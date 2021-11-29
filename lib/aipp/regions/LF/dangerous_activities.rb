module AIPP
  module LF

    class DangerousActivities < AIP

      include AIPP::LF::Helpers::Base

      # Map raw activities to type of activity airspace
      ACTIVITIES = {
        'AP' => { activity: :other, airspace: :dangerous_activities_area },
        'Aer' => { activity: :aeromodelling, airspace: :dangerous_activities_area },
        'Bal' => { activity: :balloon, airspace: :dangerous_activities_area },
        'Pje' => { activity: :parachuting, airspace: :dangerous_activities_area },
        'TrPVL' => { activity: :glider_winch, airspace: :dangerous_activities_area },
        'TrPla' => { activity: :glider_winch, airspace: :dangerous_activities_area },
        'TrVL' => { activity: :glider_winch, airspace: :dangerous_activities_area },
        'Vol' => { activity: :acrobatics, airspace: :dangerous_activities_area }
      }.freeze

      def parse
        ACTIVITIES.each do |code, type|
          verbose_info("processing #{code}")
          cache.espace.css(%Q(Espace[lk^="[LF][#{code} "])).each do |espace_node|
            partie_node = cache.partie.at_css(%Q(Partie:has(Espace[pk="#{espace_node['pk']}"])))
            volume_node = cache.volume.at_css(%Q(Volume:has(Partie[pk="#{partie_node['pk']}"])))
            add(
              AIXM.airspace(
                source: source(section: 'ENR', position: espace_node.line),
                id: espace_node.(:Nom),
                type: type[:airspace],
                local_type: code.upcase,
                name: [espace_node.(:Nom), partie_node.(:NomUsuel)].join(' ')
              ).tap do |airspace|
                airspace.geometry = geometry_from partie_node.(:Contour)
                layer_from(volume_node).then do |layer|
                  layer.activity = type[:activity]
                  airspace.add_layer layer
                end
                airspace.layers.first.timetable = timetable_from(volume_node.(:HorCode))
                airspace.layers.first.remarks = volume_node.(:Remarque)
              end
            )
          end
        end
      end

    end
  end
end
