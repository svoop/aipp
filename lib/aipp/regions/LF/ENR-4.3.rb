module AIPP
  module LF
    class ENR43 < AIP
      using AIPP::Refinements

      def parse
        html.css('tbody').each do |tbody|
          tbody.css('tr').to_enum.with_index(1).each do |tr, index|
            tds = cleanup(node: tr).css('td')
            designated_point = AIXM.designated_point(
              type: :icao,
              id: tds[0].text.strip,
              xy: xy_from(tds[1])
            )
            designated_point.region = 'LF'
            designated_point.source = source_for(tr)
            aixm.features << designated_point
          rescue => exception
            warn("error parsing designated point at ##{index}: #{exception.message}", binding)
          end
        end
      end

      private

      def source_for(tr)
        ['LF', 'ENR', 'ENR-4.3', options[:airac].date.xmlschema, line(node: tr)].join('|')
      end

      def xy_from(td)
        parts = td.text.strip.split(/\s+/)
        AIXM.xy(lat: parts[0], long: parts[1])
      end
    end
  end
end
