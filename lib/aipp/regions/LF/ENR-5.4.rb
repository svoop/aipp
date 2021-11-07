module AIPP
  module LF

    # Obstacles
    class ENR54 < AIP

      include AIPP::LF::Helpers::Base

      # Obstacles to be ignored
      NAME_DENYLIST = %w(37071 59039).freeze   # two obstacles on top of each other

      # Map type descriptions to AIXM types and remarks
      TYPES = {
        'Antenne' => [:antenna],
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
        a = prepare(html: read).css('h4:contains("5.4-1") ~ table:first a[href*="Obstacles"]:first').first
        xlsx = read(a[:href].cleanup.remove(/^.*\//))
        sheet = xlsx.sheet(xlsx.sheets.find(/^data/i).first)
        sheet.each(
          name: 'IDENTIFICATEUR',
          type: 'TYPE',
          count: 'nombre',
          longitude: 'LONGITUDE DECIMALE',
          latitude: 'LATITUDE DECIMALE',
          elevation: 'ALTITUDE AU SOMMET',
          height: 'ALTITUDE AU SOMMET',
          height_unit: 'UNITE',
          horizontal_accuracy: 'PRECISION HORIZONTALE',
          vertical_accuracy: 'PRECISION VERTICALE',
          visibility: 'BALISAGE',
          remarks: 'REMARK',
          updated_on: 'DATE DE DERNIERE MISE A JOUR'
        ).with_index(0) do |row, index|
          next unless row[:updated_on].to_s.match? /\d{8}/
          next if NAME_DENYLIST.include? row[:name]
          type, type_remarks = TYPES.fetch(row[:type])
          count = row[:count].to_i
          obstacle = AIXM.obstacle(
            source: source(position: index),
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
            obstacle.remarks = remarks_from(
              type_remarks,
              (count if count > 0),
              row[:remarks],
              (row[:updated_on].to_s.unpack("a4a2a2").join("-") if row[:updated_on])
            )
            if aixm.features.find_by(:obstacle, xy: obstacle.xy).any?
              warn("duplicate obstacle #{obstacle.name}", severe: false, pry: binding)
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
        rescue => error
          warn("error parsing obstacle at ##{index}: #{error.message}", pry: error)
        end
      end

      private

      def remarks_from(*parts)
        part_titles = ['TYPE', 'NUMBER/NOMBRE', 'DETAILS', 'UPDATED/MISE A JOUR']
        [].tap do |remarks|
          parts.each.with_index do |part, index|
            if part
              part = part.to_s.cleanup.blank_to_nil
              remarks << "**#{part_titles[index]}**\n#{part}"
            end
          end
        end.join("\n\n").blank_to_nil
      end
    end
  end
end
