module AIPP
  module LF

    # Designated Points
    class ENR43 < AIP

      include AIPP::LF::Helpers::Common

      def parse
        prepare(html: read).css('tbody').each do |tbody|
          tbody.css('tr').to_enum.with_index(1).each do |tr, index|
            tds = tr.css('td')
            designated_point = AIXM.designated_point(
              type: :icao,
              id: tds[0].text.strip,
              xy: xy_from(tds[1].text)
            )
            designated_point.source = source(position: tr.line)
            add designated_point
          rescue => error
            warn("error parsing designated point at ##{index}: #{error.message}", pry: error)
          end
        end
      end

    end
  end
end
