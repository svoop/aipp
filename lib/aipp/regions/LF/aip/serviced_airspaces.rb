module AIPP::LF::AIP
  class ServicedAirspaces < AIPP::AIP::Parser

    include AIPP::LF::Helpers::Base

    depends_on :Aerodromes

    # Map source types to type and optional local type and skip regexp
    SOURCE_TYPES = {
      'FIR' => { type: 'FIR' },
      'UIR' => { type: 'UIR' },
      'UTA' => { type: 'UTA' },
      'CTA' => { type: 'CTA' },
      'LTA' => { type: 'CTA', local_type: 'LTA' },
      'TMA' => { type: 'TMA', skip: /geneve/i },   # Geneva listed FYI only
      'SIV' => { type: 'SECTOR', local_type: 'FIZ/SIV' },   # providing FIS
      'CTR' => { type: 'CTR' },
      'RMZ' => { type: 'RMZ' },
      'TMZ' => { type: 'TMZ' },
      'RMZ-TMZ' => { type: ['RMZ', 'TMZ'] }   # two separate airspaces
    }.freeze

    # Map airspace "<type> <name>" to location indicator
    FIR_LOCATION_INDICATORS = {
      'BORDEAUX' => 'LFBB',
      'BREST' => 'LFRR',
      'MARSEILLE' => 'LFMM',
      'PARIS' => 'LFFF',
      'REIMS' => 'LFRR'
    }.freeze

    DELEGATED_RE = /(?:deleg\.|delegated|delegation)/i.freeze

    def parse
      SOURCE_TYPES.each do |source_type, target|
        verbose_info("processing #{source_type}")
        AIPP.cache.espace.css(%Q(Espace[lk^="[LF][#{source_type} "])).each do |espace_node|
          next if espace_node.(:Nom).match? DELEGATED_RE
          next if (re = target[:skip]) && espace_node.(:Nom).match?(re)
          # Build airspaces and layers
          partie_nodes = AIPP.cache.partie.css(%Q(Partie:has(Espace[pk="#{espace_node['pk']}"])))
          partie_nodes.each_with_index do |partie_node, index|
            next if partie_node.(:NomPartie).match? DELEGATED_RE
            partie_nom = partie_node.(:NomPartie).remove(/^\.$/).blank_to_nil
            partie_index = if partie_nodes.count > 1
              if partie_nom.match?(/^\d+$/)
                partie_nom.to_i   # use declared index if numerical...
              else
                index   # ...or positional index otherwise
              end
            end
            [target[:type]].flatten.each do |type|
              add(
                AIXM.airspace(
                  source: source(part: 'ENR', position: espace_node.line),
                  id: id_from(espace_node, partie_index),
                  name: name_from(espace_node, partie_nom),
                  type: type,
                  local_type: target[:local_type]
                ).tap do |airspace|
                  airspace.meta = espace_node.attr('pk')
                  airspace.geometry = geometry_from(partie_node.(:Contour))
                  fail("geometry is not closed") unless airspace.geometry.closed?
                  AIPP.cache.volume.css(%Q(Volume:has(Partie[pk="#{partie_node['pk']}"]))).each do |volume_node|
                    airspace.add_layer(
                      layer_from(volume_node).tap do |layer|
                        layer.location_indicator = FIR_LOCATION_INDICATORS.fetch(airspace.name) if airspace.type == :flight_information_region
                      end
                    )
                  end
                end
              )
            end
          end
        end
      end
    end

    private

    def id_from(espace_node, partie_index)
      if espace_node.(:TypeEspace) == 'CTR' &&
        (ad_pk = espace_node.at_css(:AdAssocie)&.attr('pk')) &&
        (airport = find_by(:airport, meta: ad_pk).first)
      then
        [airport.id, partie_index].join
      end
    end

    def name_from(espace_node, partie_nom)
      [espace_node.(:Nom), partie_nom].compact.join(' ')
    end
  end
end
