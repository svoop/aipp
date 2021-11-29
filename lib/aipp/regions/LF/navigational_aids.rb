module AIPP
  module LF

    class NavigationalAids < AIP

      include AIPP::LF::Helpers::Base

      SOURCE_TYPES = {
        'DME-ATT' => [:dme],
        'TACAN' => [:tacan],
        'VOR' => [:vor],
        'VOR-DME' => [:vor, :dme],
        'VORTAC' => [:vor, :tacan],
        'NDB' => [:ndb]
      }.freeze

      def parse
        SOURCE_TYPES.each do |source_type, (primary_type, secondary_type)|
          verbose_info("processing #{source_type}")
          cache.navfix.css(%Q(NavFix[lk^="[LF][#{source_type} "])).each do |navfix_node|
            attributes = {
              source: source(section: 'ENR', position: navfix_node.line),
              organisation: organisation_lf,
              id: navfix_node.(:Ident),
              xy: xy_from(navfix_node.(:Geometrie))
            }
            if radionav_node = cache.radionav.at_css(%Q(RadioNav:has(NavFix[pk="#{navfix_node.attr(:pk)}"])))
              attributes.merge! send(primary_type, radionav_node)
              add(
                AIXM.send(primary_type, **attributes).tap do |navigational_aid|
                  navigational_aid.name = radionav_node.(:NomPhraseo) || radionav_node.(:Station)
                  navigational_aid.timetable = timetable_from(radionav_node.(:HorCode))
                  navigational_aid.remarks = {
                    "location/situation" => radionav_node.(:Situation),
                    "range/portée" => range_from(radionav_node)
                  }.to_remarks
                  navigational_aid.send("associate_#{secondary_type}") if secondary_type
                end
              )
            else
              verbose_info("skipping incomplete #{source_type} #{attributes[:id]}")
            end
          end
        end
      end

      private

      def dme(radionav_node)
        {
          ghost_f: AIXM.f(radionav_node.(:Frequence).to_f, :mhz),
          z: AIXM.z(radionav_node.(:AltitudeFt).to_i, :qnh)
        }
      end
      alias_method :tacan, :dme

      def vor(radionav_node)
        {
          type: :conventional,
          north: :magnetic,
          name: radionav_node.(:Station),
          f: AIXM.f(radionav_node.(:Frequence).to_f, :mhz),
          z: AIXM.z(radionav_node.(:AltitudeFt).to_i, :qnh),
        }
      end

      def ndb(radionav_node)
        {
          type: :en_route,
          f: AIXM.f(radionav_node.(:Frequence).to_f, :khz),
          z: AIXM.z(radionav_node.(:AltitudeFt).to_i, :qnh)
        }
      end

      def range_from(radionav_node)
        [
          radionav_node.(:Portee).blank_to_nil&.concat('NM'),
          radionav_node.(:FlPorteeVert).blank_to_nil&.prepend('FL'),
          radionav_node.(:Couverture).blank_to_nil
        ].compact.join(' / ')
      end

    end
  end
end
