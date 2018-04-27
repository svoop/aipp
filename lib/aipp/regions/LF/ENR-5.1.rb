module AIPP
  module LF
    class ENR51 < AIP
      using AIPP::Refinements
      using AIXM::Refinements

      TYPES = {
        'D' => 'D',
        'P' => 'P',
        'R' => 'R',
        'ZIT' => 'P'
      }.freeze

      BORDERS = {
        'franco-allemande' => 'FRANCE_GERMANY',
        'franco-espagnole' => 'FRANCE_SPAIN',
        'franco-italienne' => 'FRANCE_ITALY',
        'franco-suisse' => 'FRANCE_SWITZERLAND',
        'franco-luxembourgeoise' => 'FRANCE_LUXEMBOURG',
        'franco-belge' => 'BELGIUM_FRANCE'
      }.freeze

      def parse
        html.css('tbody:has(tr[id^=mid])').each do |tbody|
          airspace = nil
          tbody.css('tr').to_enum.with_index(1).each do |tr, index|
            if tr.attr(:class) =~ /keep-with-next-row/
              airspace = airspace_from cleanup(node: tr)
            else
              begin
                tds = cleanup(node: tr).css('td')
                airspace.geometry = geometry_from tds[0]
                fail("geometry is not closed") unless airspace.geometry.closed? 
                airspace.layers << layer_from(tds[1])
                airspace.layers.first.timetable = timetable_from tds[2]
                airspace.layers.first.remarks = remarks_from(tds[2], tds[3], tds[4])
                aixm.features << airspace
              rescue => exception
                warn("error parsing airspace `#{airspace.name}' at ##{index}: #{exception.message}", binding)
              end
            end
          end
        end
      end

      private

      def airspace_from(tr)
        spans = tr.css(:span)
        AIXM.airspace(
          name: [spans[1], spans[2], spans[3], spans[5].text.blank_to_nil].compact.join(' '),
          short_name: [spans[1], spans[2], spans[3]].compact.join(' '),
          type: TYPES.fetch(spans[2].text)
        )
      end

      def geometry_from(td)
        AIXM.geometry.tap do |geometry|
          buffer = {}
          td.text.gsub(/\s+/, ' ').strip.split(/ - /).append('end').each do |element|
            case element
            when /frontière (.+)/i
              geometry << AIXM.border(
                xy: buffer.delete(:xy),
                name: BORDERS.fetch($1)
              )
            when /arc (anti-)?horaire .+ sur (\S+) , (\S+)/i
              geometry << AIXM.arc(
                xy: buffer.delete(:xy),
                center_xy: AIXM.xy(lat: $2, long: $3),
                clockwise: $1.nil?
              )
            when /cercle de ([\d\.]+) (NM|km|m) .+ sur (\S+) , (\S+)/i
              geometry << AIXM.circle(
                center_xy: AIXM.xy(lat: $3, long: $4),
                radius: $1.to_f.to_km(from: $2).round(3)
              )
            when /end|(\S+) , (\S+)/
              geometry << AIXM.point(xy: buffer[:xy]) if buffer.has_key?(:xy)
              buffer[:xy] = AIXM.xy(lat: $1, long: $2) if $1
            else
              fail "geometry `#{element}' not recognized"
            end
          end
        end
      end

      def layer_from(td)
        above, below = td.text.gsub(/ /, '').split(/\n+/).select(&:blank_to_nil).split(/---+/)
        above.reverse!
        AIXM.layer(
          vertical_limits: AIXM.vertical_limits(
            max_z: z_from(above[1]),
            upper_z: z_from(above[0]),
            lower_z: z_from(below[0]),
            min_z: z_from(below[1])
          )
        )
      end

      def z_from(limit)
        case limit
          when nil then nil
          when 'SFC' then AIXM::GROUND
          when 'UNL' then AIXM::UNLIMITED
          when /(\d+)ftASFC/ then AIXM.z($1.to_i, :qfe)
          when /(\d+)ftAMSL/ then AIXM.z($1.to_i, :qnh)
          when /FL(\d+)/ then AIXM.z($1.to_i, :qne)
          else fail "z `#{limit}' not recognized"
        end
      end

      def timetable_from(td)
        AIXM::H24 if td.text.gsub(/\W/, '') == 'H24'
      end

      def remarks_from(*parts)
        part_titles = ['TIMETABLE', 'RESTRICTION', 'AUTHORITY/CONDITIONS']
        [].tap do |remarks|
          parts.each.with_index do |part, index|
            if part = part.text.gsub(/ +/, ' ').gsub(/(\n ?)+/, "\n").strip.blank_to_nil
              unless index.zero? && part == 'H24'
                remarks << "#{part_titles[index]}:\n#{part}"
              end
            end
          end
        end.join("\n\n").blank_to_nil
      end
    end
  end
end
