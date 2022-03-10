module AIPP::LF::AIP
  class DPRAirspaces < AIPP::AIP::Parser

    include AIPP::LF::Helpers::Base

    # Map source types to type and optional local type
    SOURCE_TYPES = {
      'D' => { type: 'D' },
      'P' => { type: 'P' },
      'R' => { type: 'R' },
      'ZIT' => { type: 'P', local_type: 'ZIT' }
    }.freeze

    # Radius to use for zones consisting of one point only
    POINT_RADIUS = AIXM.d(1, :km).freeze

    def parse
      SOURCE_TYPES.each do |source_type, target|
        verbose_info("processing #{source_type}")
        AIPP.cache.espace.css(%Q(Espace[lk^="[LF][#{source_type} "])).each do |espace_node|
# UPSTREAM: Espace[pk=300343] has no Partie/Volume (reported)
next if espace_node['pk'] == '300343'
          partie_node = AIPP.cache.partie.at_css(%Q(Partie:has(Espace[pk="#{espace_node['pk']}"])))
          volume_node = AIPP.cache.volume.at_css(%Q(Volume:has(Partie[pk="#{partie_node['pk']}"])))
          name = "#{AIPP.options.region}-#{source_type}#{espace_node.(:Nom)}".remove(/\s/)
          add(
            AIXM.airspace(
              source: source(part: 'ENR', position: espace_node.line),
              name: "#{name} #{partie_node.(:NomUsuel)}".strip,
              type: target[:type],
              local_type: target[:local_type]
            ).tap do |airspace|
              airspace.geometry = geometry_from(partie_node.(:Contour))
              if airspace.geometry.point?   # convert point to circle
                airspace.geometry = AIXM.geometry(
                  AIXM.circle(
                    center_xy: airspace.geometry.segments.first.xy,
                    radius: POINT_RADIUS
                  )
                )
              end
              fail("geometry is not closed") unless airspace.geometry.closed?
              airspace.add_layer layer_from(volume_node)
              airspace.layers.first.timetable = timetable_from(volume_node.(:HorCode))
              airspace.layers.first.remarks = volume_node.(:Activite)
            end
          )
        end
      end
    end

  end
end
