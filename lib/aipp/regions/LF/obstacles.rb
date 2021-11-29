module AIPP
  module LF

    class Obstacles < AIP

      include AIPP::LF::Helpers::Base

      # Map type descriptions to AIXM types and remarks
      TYPES = {
        'Antenne' => [:antenna],
        'Autre' => [:other],
        'Bâtiment' => [:building],
        'Câble' => [:other, 'Cable / Câble'],
        'Centrale thermique' => [:building, 'Thermal power plant / Centrale thermique'],
        "Château d'eau" => [:tower, "Water tower / Château d'eau"],
        'Cheminée' => [:chimney],
        'Derrick' => [:tower, 'Derrick'],
        'Eglise' => [:tower, 'Church / Eglise'],
        'Eolienne' => [:wind_turbine],
        'Eolienne(s)' => [:wind_turbine],
        'Grue' => [:tower, 'Crane / Grue'],
        'Mât' => [:mast],
        'Phare marin' => [:tower, 'Lighthouse / Phare marin'],
        'Pile de pont' => [:other, 'Bridge piers / Pile de pont'],
        'Portique' => [:building, 'Arch / Portique'],
        'Pylône' => [:mast, 'Pylon / Pylône'],
        'Silo' => [:tower, 'Silo'],
        'Terril' => [:other, 'Spoil heap / Teril'],
        'Torchère' => [:chimney, 'Flare / Torchère'],
        'Tour' => [:tower],
        'Treillis métallique' => [:other, 'Metallic grid / Treillis métallique']
      }.freeze

      def parse
        if options[:region_options].include? 'lf_obstacles_xlsx'
          info("reading obstacles from XLSX")
          @xlsx = read('Obstacles')
          parse_from_xlsx
        else
          parse_from_xml
        end
      end

      private

      def parse_from_xlsx
        # Build obstacles
        @xlsx.sheet(@xlsx.sheets.find(/^data/i).first).each(
          name: 'IDENTIFICATEUR',
          type: 'TYPE',
          count: 'NOMBRE',
          longitude: 'LONGITUDE DECIMALE',
          latitude: 'LATITUDE DECIMALE',
          elevation: 'ALTITUDE AU SOMMET',
          height: 'HAUTEUR HORS SOL',
          height_unit: 'UNITE',
          horizontal_accuracy: 'PRECISION HORIZONTALE',
          vertical_accuracy: 'PRECISION VERTICALE',
          visibility: 'BALISAGE',
          remarks: 'REMARK',
          effective_on: 'DATE DE MISE EN VIGUEUR'
        ).with_index(0) do |row, index|
          next unless row[:effective_on].to_s.match? /\d{8}/
          type, type_remarks = TYPES.fetch(row[:type])
          count = row[:count].to_i
          obstacle = AIXM.obstacle(
            source: source(section: 'ENR', position: index),
            name: row[:name],
            type: type,
            xy: AIXM.xy(lat: row[:latitude].to_f, long: row[:longitude].to_f),
            z: AIXM.z(row[:elevation].to_i, :qnh)
          ).tap do |obstacle|
            obstacle.height = AIXM.d(row[:height].to_i, row[:height_unit])
            if row[:horizontal_accuracy]
              accuracy = row[:horizontal_accuracy].split
              obstacle.xy_accuracy = AIXM.d(accuracy.first.to_i, accuracy.last)
            end
            if row[:vertical_accuracy]
              accuracy = row[:horizontal_accuracy].split
              obstacle.z_accuracy = AIXM.d(accuracy.first.to_i, accuracy.last)
            end
            obstacle.marking = row[:visibility].match?(/jour/i)
            obstacle.lighting = row[:visibility].match?(/nuit/i)
            obstacle.remarks = {
              'type' => type_remarks,
              'number/nombre' => (count if count > 1),
              'details' => row[:remarks],
              'effective/mise en vigueur' => (row[:effective_on].to_s.unpack("a4a2a2").join("-") if row[:updated_on])
            }.to_remarks
            # Group obstacles
            if aixm.features.find_by(:obstacle, xy: obstacle.xy).any?
              warn("duplicate obstacle #{obstacle.name}", severe: false)
            else
              if count > 1
                obstacle_group = AIXM.obstacle_group(
                  source: obstacle.source,
                  name: obstacle.name
                ).tap do |obstacle_group|
                  obstacle_group.remarks = "#{count} obstacles"
                end
                obstacle_group.add_obstacle obstacle
                add obstacle_group
              else
                add obstacle
              end
            end
          end
        end
      end

      def parse_from_xml
        cache.obstacle.css(%Q(Obstacle[lk^="[LF]"])).each do |node|
          # Build obstacles
          type, type_remarks = TYPES.fetch(node.(:TypeObst))
          count = node.(:Combien).to_i
          obstacle = AIXM.obstacle(
            source: source(section: 'ENR', position: node.line),
            name: node.(:NumeroNom),
            type: type,
            xy: xy_from(node.(:Geometrie)),
            z: AIXM.z(node.(:AmslFt).to_i, :qnh)
          ).tap do |obstacle|
            obstacle.height = AIXM.d(node.(:AglFt).to_i, :ft)
            obstacle.marking = node.(:Balisage).match?(/jour/i)
            obstacle.lighting = node.(:Balisage).match?(/nuit/i)
            obstacle.remarks = {
              'type' => type_remarks,
              'number/nombre' => (count if count > 1)
            }.to_remarks
          end
          # Group obstacles
          if aixm.features.find_by(:obstacle, xy: obstacle.xy).any?
            warn("duplicate obstacle #{obstacle.name}", severe: false)
          else
            if count > 1
              obstacle_group = AIXM.obstacle_group(
                source: obstacle.source,
                name: obstacle.name
              ).tap do |obstacle_group|
                obstacle_group.remarks = "#{count} obstacles"
              end
              obstacle_group.add_obstacle obstacle
              add obstacle_group
            else
              add obstacle
            end
          end
        end
      end

    end
  end
end
