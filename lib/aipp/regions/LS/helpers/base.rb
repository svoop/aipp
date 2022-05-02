module AIPP
  module LS
    module Helpers
      module Base

        using AIXM::Refinements

        # Mandatory Interface

        def setup
          AIPP.cache.aip = read('AIP').css('Ase')
#         AIPP.cache.dabs = read('DABS')
        end

        def url_for(document)
          case document
          when 'ENR'
            # sql = <<~END
            #   SELECT id, effectiveFrom, validUntil, notam
            #     FROM notam
            #     WHERE substr(id, 10, 2) IN ('LS') AND
            #       substr(id, 1, 1) IN ('B', 'W') AND
            #       effectiveFrom < '#{aixm.expiration_at}' AND
            #       validUntil > '#{aixm.effective_at.beginning_of_day}'
            #     ORDER BY id
            # END
            # "mysql://%s?command=%s" % [
            #   ENV.fetch('DB_URL', 'cloudsqlproxy@127.0.0.1:33306/notam'),
            #   CGI.escape(sql)
            # ]
          when 'AD'
            fail "not yet implemented"
          when 'AIP'
            airac = AIRAC::Cycle.new
            "https://snapshots.openflightmaps.org/live/#{airac.id}/ofmx/lsas/latest/ofmx_ls.zip#ofmx_ls/isolated/ofmx_ls.ofmx"
          when 'DABS'
            "pdf+https://www.skybriefing.com/dabs?p_p_id=ch_skyguide_ibs_portal_dabs_DabsUI&p_p_lifecycle=2&p_p_state=normal&p_p_mode=view&p_p_resource_id=APP&p_p_cacheability=cacheLevelPage&_ch_skyguide_ibs_portal_dabs_DabsUI_v-resourcePath=%2FAPP%2Fconnector%2F0%2F2%2Fhref%2Fdabs-#{aixm.effective_at.to_date}.pdf"
          else
            fail "document not recognized"
          end
        end

        # Templates

        def organisation_lf
          unless AIPP.cache.organisation_lf
            AIPP.cache.organisation_lf = AIXM.organisation(
              source: source(position: 1, document: "GEN-3.1"),
              name: 'SWITZERLAND',
              type: 'S'
            ).tap do |organisation|
              organisation.id = 'LS'
            end
            add AIPP.cache.organisation_ls
          end
          AIPP.cache.organisation_ls
        end

        # Parserettes

        def timetable_from(schedules)
          AIXM.timetable.tap do |timetable|
            schedules&.each do |schedule|
              schedule.actives.each do |actives|
                schedule.times.each do |times|
                  timesheet = AIXM.timesheet(
                    adjust_to_dst: false,
                    dates: (actives.instance_of?(Range) ? actives : (actives..actives))
                    # TODO: transform to...
                    # dates: actives
                  )
                  timesheet.times = times
                  timetable.add_timesheet timesheet
                end
              end
            end
          end
        end

      end
    end
  end
end
