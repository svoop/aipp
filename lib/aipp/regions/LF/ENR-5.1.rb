module AIPP
  module LF

    # D/P/R Zones
    class ENR51 < AIP

      include AIPP::LF::Helpers::Common

      # Map source types to type and optional local type
      SOURCE_TYPES = {
        'D' => { type: 'D' },
        'P' => { type: 'P' },
        'R' => { type: 'R' },
        'ZIT' => { type: 'P', local_type: 'ZIT' }
      }.freeze

      def parse
        prepare(html: read).css('tbody:has(tr[id^=mid])').each do |tbody|
          airspace = nil
          tbody.css('tr').to_enum.with_index(1).each do |tr, index|
            tds = tr.css('td')
            case
            when tr.attr(:id).match?(/TXT_NAME/)   # airspace
              airspace = airspace_from tr
            when tds.count == 1   # big comment on separate row
              airspace.layers.first.remarks.
                concat("\n", tds.text.cleanup).
                remove!(/\((\d)\)\s*\(\1\)\W*/)
            else   # layer
              begin
                tds = tr.css('td')
                airspace.geometry = geometry_from tds[0].text
                fail("geometry is not closed") unless airspace.geometry.closed?
                airspace.layers << layer_from(tds[1].text)
                airspace.layers.first.timetable = timetable_from tds[2].text
                airspace.layers.first.remarks = remarks_from(tds[2], tds[3], tds[4])
                add airspace
              rescue => error
                warn("error parsing airspace `#{airspace.name}' at ##{index}: #{error.message}", pry: error)
              end
            end
          end
        end
      end

      private

      def airspace_from(tr)
        spans = tr.css('span:not([class*=strong])')
        source_type = spans[1].text.blank_to_nil
        fail "unknown type `#{source_type}'" unless SOURCE_TYPES.has_key? source_type
        AIXM.airspace(
          name: spans.map { |s| s.text.strip.blank_to_nil }.compact.join(' '),
          type: SOURCE_TYPES.dig(source_type, :type),
          local_type: SOURCE_TYPES.dig(source_type, :local_type)
        ).tap do |airspace|
          airspace.source = source(position: tr.line)
        end
      end

      def remarks_from(*parts)
        part_titles = ['TIMETABLE', 'RESTRICTION', 'AUTHORITY/CONDITIONS']
        [].tap do |remarks|
          parts.each.with_index do |part, index|
            if part = part.text.gsub(/ +/, ' ').gsub(/(\n ?)+/, "\n").strip.blank_to_nil
              unless index.zero? && part == 'H24'
                remarks << "**#{part_titles[index]}**\n#{part}"
              end
            end
          end
        end.join("\n\n").blank_to_nil
      end
    end
  end
end
