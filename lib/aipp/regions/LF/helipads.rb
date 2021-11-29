module AIPP
  module LF

    class Helipads < AIP

      include AIPP::LF::Helpers::Base
      include AIPP::LF::Helpers::UsageLimitation
      include AIPP::LF::Helpers::Surface

      DEPENDS = %w(aerodromes)

      HOSTILITIES = {
        'hostile habitée' => 'Zone hostile habitée / hostile populated area',
        'hostile non habitée' => 'Zone hostile non habitée / hostile unpopulated area',
        'non hostile' => 'Zone non hostile / non-hostile area'
      }.freeze

      ELEVATED = {
        true => 'En terrasse / on deck',
        false => 'En surface / on ground'
      }.freeze

      def parse
        cache.helistation.css(%Q(Helistation[lk^="[LF]"])).each do |helistation_node|
          # Build airport if necessary
          next unless limitation_type = LIMITATION_TYPES.fetch(helistation_node.(:Statut))
          name = helistation_node.(:Nom)
          airport = find_by(:airport, name: name).first || add(
            AIXM.airport(
              source: source(section: 'AD', position: helistation_node.line),
              organisation: organisation_lf,
              id: options[:region],
              name: name,
              xy: xy_from(helistation_node.(:Geometrie))
            ).tap do |airport|
              airport.z = AIXM.z(helistation_node.(:AltitudeFt).to_i, :qnh)
              airport.add_usage_limitation(type: limitation_type.fetch(:limitation)) do |limitation|
                limitation.remarks = limitation_type[:remarks]
                [:private].each do |purpose|   # TODO: check and simplify
                  limitation.add_condition do |condition|
                    condition.realm = limitation_type.fetch(:realm)
                    condition.origin = :any
                    condition.rule = case
                      when helistation_node.(:Ifr?) then :ifr_and_vfr
                      else :vfr
                    end
                    condition.purpose = purpose
                  end
                end
              end
            end
          )
# TODO: link to VAC once supported downstream
#         # Link to VAC
#         if helistation_node.(:Atlas?)
#           vac = "VAC-#{airport.id}" if airport.id.match?(/^LF[A-Z]{2}$/)
#           vac ||= "VACH-H#{airport.name[0, 3].upcase}"
#           airport.remarks = [
#             airport.remarks.to_s,
#             link_to('VAC-HP', url_for(vac))
#           ].join("\n")
#         end
          # Add helipad and FATO
          airport.add_helipad(
            AIXM.helipad(
              name: 'TLOF',
              xy: xy_from(helistation_node.(:Geometrie))
            ).tap do |helipad|
              helipad.z = AIXM.z(helistation_node.(:AltitudeFt).to_i, :qnh)
              helipad.dimensions = dimensions_from(helistation_node.(:DimTlof))
            end.tap do |helipad|
              airport.add_helipad(helipad)
              helipad.performance_class = performance_class_from(helistation_node.(:ClassePerf))
              helipad.surface = surface_from(helistation_node)
              helipad.marking = helistation_node.(:Balisage) unless helistation_node.(:Balisage)&.match?(/^nil$/i)
              helipad.add_lighting(AIXM.lighting(position: :other)) if helistation_node.(:Nuit?) || helistation_node.(:Balisage)&.match?(/feu/i)
              helipad.remarks = {
                'position/positioning' => [
                  (HOSTILITIES.fetch(helistation_node.(:ZoneHabitee)) if helistation_node.(:ZoneHabitee)),
                  (ELEVATED.fetch(helistation_node.(:EnTerrasse?)) if helistation_node.(:EnTerrasse)),
                ].compact.join("\n"),
                'hauteur/height' => given(helistation_node.(:HauteurFt)) { "#{_1} ft" },
                'exploitant/operator' => helistation_node.(:Exploitant)
              }.to_remarks
              if fato_dimensions = dimensions_from(helistation_node.(:DimFato))
                AIXM.fato(name: 'FATO').tap do |fato|
                  fato.dimensions = fato_dimensions
                  airport.add_fato(fato)
                  helipad.fato = fato
                end
              end
            end
          )
        end
      end

      private

      def dimensions_from(content)
        if content
          dims = content.remove(/[^x\d.,]/i).split(/x/i).map { _1.to_ff.floor }
          case dims.size
          when 1
            AIXM.r(AIXM.d(dims[0], :m))
          when 2
            AIXM.r(AIXM.d(dims[0], :m), AIXM.d(dims[1], :m))
          when 4
            AIXM.r(AIXM.d(dims.min, :m))
          else
            warn("ignoring dimensions `#{content}'", severe: false)
            nil
          end
        end
      end

      def performance_class_from(content)
        content.remove(/\d{2,}/).scan(/\d/).map(&:to_i).min&.to_s if content
      end

    end
  end
end
