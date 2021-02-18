module AIPP
  module LF
    module Helpers
      module NavigationalAid

        def navigational_aid_from(tds, source:, sections:)
          NavigationalAid.new(tds, source: source, sections: sections, organisation: cache.organisation_lf).build
        end

        class NavigationalAid
          include AIPP::LF::Helpers::Base

          # Map atypical navigational aid denominations
          NAVIGATIONAL_AIDS = {
            'vor' => 'vor',
            'dme' => 'dme',
            'ndb' => 'ndb',
            'tacan' => 'tacan',
            'l' => 'ndb'   # L denominates a NDB of class locator
          }.freeze

          def initialize(tds, source:, sections:, organisation:)
            @tds, @source, @sections, @organisation = tds, source, sections, organisation
          end

          def build
            primary, secondary = @tds[:type].text.strip.gsub(/[^\w-]/, '').downcase.split('-')
            primary = NAVIGATIONAL_AIDS.fetch(primary, primary)
            secondary = NAVIGATIONAL_AIDS.fetch(secondary, secondary)
            return nil unless NAVIGATIONAL_AIDS.keys.include? primary
            AIXM.send(primary, common.merge(send(primary))).tap do |navigational_aid|
              navigational_aid.source = @source
              navigational_aid.remarks = remarks
              navigational_aid.timetable = timetable_from!(@tds[:schedule].text)
              navigational_aid.send("associate_#{secondary}", channel: channel_from(@tds[:f].text)) if secondary
            end
          end

          private

          def common
            {
              organisation: @organisation,
              id: @tds[:id].text.strip,
              name: @tds[:name].text.strip,
              xy: xy_from(@tds[:xy].text),
              z: z_from(@tds[:z].text)
            }
          end

          def vor
            {
              type: :conventional,
              f: f_from(@tds[:f].text),
              north: :magnetic,
            }
          end

          def dme
            {
              channel: channel_from(@tds[:f].text)
            }
          end

          def ndb
            {
              type: @tds[:type].text.strip == 'L' ? :locator : :en_route,
              f: f_from(@tds[:f].text)
            }
          end

          def tacan
            {
              channel: channel_from(@tds[:f].text)
            }
          end

          def remarks
            @sections.map do |section, td|
              if text = td.text.strip.blank_to_nil
                "**#{section.upcase}**\n#{text}"
              end
            end.compact.join("\n\n").blank_to_nil
          end

          def z_from(text)
            parts = text.strip.split(/\s+/)
            AIXM.z(parts[0].to_i, :qnh) if parts[1] == 'ft'
          end

          def f_from(text)
            parts = text.strip.split(/\s+/)
            AIXM.f(parts[0].to_f, parts[1]) if parts[1] =~ /hz$/i
          end

          def channel_from(text)
            parts = text.strip.split(/\s+/)
            parts.last if parts[-2].downcase == 'ch'
          end
        end
      end
    end
  end
end
