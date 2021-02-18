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
            id, activity_and_name, upper_limit, timetable = trs.first.css('td')
            activity, name = activity_and_name.css('span, ins')
            airspace = AIXM.airspace(
              source: source(position: trs.first.line),
              id: id.text.strip,
              type: ACTIVITIES.fetch(activity.text.downcase).fetch(:airspace_type),
              name: [id.text.strip, name.text.cleanup].join(' ')
            ).tap do |airspace|
              lateral_limit, lower_limit, remarks = trs.last.css('td')
              lateral_limit.search('br').each { _1.replace("|||") }
              geometry, lateral_limit = lateral_limit.text.split('|||', 2)
              lateral_limit&.gsub!('|||', "\n")
              remarks = [remarks&.text&.cleanup&.blank_to_nil]
              s = timetable&.text&.cleanup and remarks.prepend('**SCHEDULE**', s, '')
              s = lateral_limit&.cleanup and remarks.prepend('**LATERAL LIMIT**', s, '')
              airspace.geometry = geometry_from(geometry)
              airspace.add_layer(
                layer_from([upper_limit.text, lower_limit.text].join('---').cleanup).tap do |layer|
                  layer.activity = ACTIVITIES.fetch(activity.text.downcase).fetch(:activity)
                  layer.remarks = remarks.compact.join("\n")
                end
              )
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
