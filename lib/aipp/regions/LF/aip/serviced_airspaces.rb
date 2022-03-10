module AIPP::LF::AIP
  class ServicedAirspaces < AIPP::AIP::Parser

    include AIPP::LF::Helpers::Base

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
      'RMZ' => { type: 'RAS', local_type: 'RMZ' },
      'TMZ' => { type: 'RAS', local_type: 'TMZ' },
      'RMZ-TMZ' => { type: 'RAS', local_type: 'RMZ-TMZ' }
    }.freeze

    # Map airspace "<type> <name>" to location indicator
    FIR_LOCATION_INDICATORS = {
      'BORDEAUX' => 'LFBB',
      'BREST' => 'LFRR',
      'MARSEILLE' => 'LFMM',
      'PARIS' => 'LFFF',
      'REIMS' => 'LFRR'
    }.freeze

    def parse
      SOURCE_TYPES.each do |source_type, target|
        verbose_info("processing #{source_type}")
        AIPP.cache.espace.css(%Q(Espace[lk^="[LF][#{source_type} "])).each do |espace_node|
          # Skip all delegated airspaces
          next if espace_node.(:Nom).match? /deleg/i
          next if (re = target[:skip]) && espace_node.(:Nom).match?(re)
          # Build airspaces and layers
          AIPP.cache.partie.css(%Q(Partie:has(Espace[pk="#{espace_node['pk']}"]))).each do |partie_node|
            add(
              AIXM.airspace(
                source: source(part: 'ENR', position: espace_node.line),
                name: [
                  espace_node.(:Nom),
                  partie_node.(:NomPartie).remove(/^\.$/).blank_to_nil
                ].compact.join(' '),
                type: target[:type],
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
end
