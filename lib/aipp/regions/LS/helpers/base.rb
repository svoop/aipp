module AIPP
  module NewayAPI
    HttpAdapter = GraphQL::Client::HTTP.new(ENV['NEWAY_API_URL']) do
      def headers(context)
        { "Authorization": "Bearer #{ENV['NEWAY_API_AUTHORIZATION']}" }
      end
    end
    Schema = GraphQL::Client.load_schema(HttpAdapter)
    Client = GraphQL::Client.new(schema: Schema, execute: HttpAdapter)

    class Notam
      Query = Client.parse <<~END
        query ($region: String!, $series: [String!], $start: Int!, $end: Int!) {
          queryNOTAMs(
            filter: {region: $region, series: $series, start: $start, end: $end}
          ) {
            notamRaw
          }
        }
      END
    end
  end

  module LS
    module Helpers
      module Base

        using AIXM::Refinements

        # Mandatory Interface

        def setup
          AIPP.cache.aip = read('AIP').css('Ase')
#         AIPP.cache.dabs = read('DABS')
        end

        def origin_for(document)
          case document
          when 'ENR'
            AIPP::Downloader::GraphQL.new(
              client: AIPP::NewayAPI::Client,
              query: AIPP::NewayAPI::Notam::Query,
              variables: {
                region: 'LS',
                series: %w(W B),
                start: aixm.expiration_at.to_i,
                end: aixm.effective_at.beginning_of_day.to_i
              }
            )
          when 'AD'
            fail "not yet implemented"
          when 'AIP'
            AIPP::Downloader::HTTP.new(
              archive: "https://snapshots.openflightmaps.org/live/#{AIRAC::Cycle.new.id}/ofmx/lsas/latest/ofmx_ls.zip",
              file: "ofmx_ls/isolated/ofmx_ls.ofmx"
            )
          when 'DABS'
            AIPP::Downloader::HTTP.new(
              file: "https://www.skybriefing.com/dabs?p_p_id=ch_skyguide_ibs_portal_dabs_DabsUI&p_p_lifecycle=2&p_p_state=normal&p_p_mode=view&p_p_resource_id=APP&p_p_cacheability=cacheLevelPage&_ch_skyguide_ibs_portal_dabs_DabsUI_v-resourcePath=%2FAPP%2Fconnector%2F0%2F2%2Fhref%2Fdabs-#{aixm.effective_at.to_date}.pdf",
              type: :pdf
            )
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
