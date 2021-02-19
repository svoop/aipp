module AIPP
  module LF

    # Designated Points
    class ENR44 < AIP

      include AIPP::LF::Helpers::Base

      def parse
        prepare(html: read).css('tbody').each do |tbody|
          tbody.css('tr').to_enum.with_index(1).each do |tr, index|
            tds = tr.css('td')
            add AIXM.designated_point(
              source: source(position: tr.line),
              type: :icao,
              id: tds[0].text.strip,
              xy: xy_from(tds[1].text)
            )
          rescue => error
            warn("error parsing designated point at ##{index}: #{error.message}", pry: error)
          end
        end
      end

    end
  end
end
