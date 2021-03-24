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
        tbody = prepare(html: read).css('tbody').last
        tbody.css('tr').to_enum.with_index(1).each do |tr, index|
          tds = tr.css('td')
          name = tds[0].text.cleanup
          next if NAME_DENYLIST.include? name
          elevation, height = tds[4].text.cleanup.split(/[()]/).map { _1.cleanup.remove("\n") }
          type, type_remarks = TYPES.fetch(tds[2].text.cleanup)
          count = tds[3].text.cleanup.to_i
          visibility = tds[5].text.cleanup
          obstacle = AIXM.obstacle(
            source: source(position: tr.line),
            name: name,
            type: type,
            xy: xy_from(tds[1].text),
            z: z_from(elevation + 'AMSL')
          ).tap do |obstacle|
            obstacle.height = d_from(height)
            obstacle.height_accurate = true
            obstacle.marking = visibility.match?(/jour/i)
            obstacle.lighting = visibility.match?(/nuit/i)
            obstacle.remarks = remarks_from(type_remarks, (count if count > 1), tds[6].text)
          end
          if aixm.features.find_by(:obstacle, xy: obstacle.xy).any?
            warn("duplicate obstacle #{name}", severe: false, pry: binding)
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
        rescue => error
          warn("error parsing obstacle at ##{index}: #{error.message}", pry: error)
        end
      end

      private

      def remarks_from(*parts)
        part_titles = ['TYPE', 'NUMBER/NOMBRE', 'DETAILS']
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
