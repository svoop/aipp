module AIPP
  module LF

    # Sporting and Recreational Activities
    class ENR55 < AIP

      include AIPP::LF::Helpers::Base

      # Map raw activities to activity and airspace type
      ACTIVITIES = {
        'activité particulière' => { activity: :other, airspace_type: :dangerous_activities_area },
        'aéromodélisme' => { activity: :aeromodelling, airspace_type: :dangerous_activities_area },
        'parachutage' => { activity: :parachuting, airspace_type: :dangerous_activities_area },
        'treuillage' => { activity: :glider_winch, airspace_type: :dangerous_activities_area },
        'voltige' =>  { activity: :acrobatics, airspace_type: :dangerous_activities_area }
      }.freeze

      def parse
        prepare(html: read).css('tbody').each do |tbody|
          tbody.css('tr').to_enum.each_slice(2).with_index(1) do |trs, index|
            begin
              id, activity_and_name, upper_limits, timetable = trs.first.css('td')
              activity, name = activity_and_name.css('span')
              lateral_limits, lower_limits, remarks = trs.last.css('td')
              lateral_limits.search('br').each { |br| br.replace("|||") }
              geometry, lateral_limits = lateral_limits.text.split('|||', 2)
              lateral_limits&.gsub!('|||', "\n")
              remarks = [remarks&.text&.cleanup&.blank_to_nil]
              s = timetable&.text&.cleanup and remarks.prepend('**SCHEDULE**', s, '')
              s = lateral_limits&.cleanup and remarks.prepend('**LATERAL LIMITS**', s, '')
              airspace = AIXM.airspace(
                source: source(position: trs.first.line),
                id: id.text.strip,
                type: ACTIVITIES.fetch(activity.text.downcase).fetch(:airspace_type),
                name: [id.text.strip, name.text.cleanup].join(' ')
              ).tap do |airspace|
                airspace.geometry = geometry_from(geometry)
                airspace.layers << layer_from([upper_limits.text, lower_limits.text].join('---').cleanup).tap do |layer|
                  layer.activity = ACTIVITIES.fetch(activity.text.downcase).fetch(:activity)
                  layer.remarks = remarks.compact.join("\n")
                end
              end
            rescue => error
              warn("error parsing #{airspace.type} `#{airspace.name}' at ##{index}: #{error.message}", pry: error)
            end
            add airspace
          end
        end
      end

    end
  end
end
