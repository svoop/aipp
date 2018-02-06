module AIPP
  module Parsers
    include Helpers::URL
    include Helpers::HTML

    def convert!
      html.css('tbody').each do |tbody|
        tbody.css('tr').to_enum.with_index(1).each do |tr, index|
          break if index >= @limit
          tds = cleanup(tr).css('td')
          designated_point = AIXM.designated_point(
            type: :icao,
            id: tds[0].text.strip,
            xy: xy_from(tds[1])
          )
          aixm.features << designated_point
        rescue => exception
          warn("WARNING: error parsing designated point at ##{index}: #{exception.message}", binding)
        end
      end
      true
    end

    private

    def xy_from(td)
      parts = td.text.strip.split(/\s+/)
      AIXM.xy(lat: parts[0], long: parts[1])
    end
  end
end
