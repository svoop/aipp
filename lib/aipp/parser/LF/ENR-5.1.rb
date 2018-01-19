module AIPP
  module Parser

    using AIPP::Refinements
    using AIXM::Refinements

    TYPES = {
      'D' => :D,
      'P' => :P,
      'R' => :R,
      'ZIT' => :P
    }.freeze

    BORDERS = {
      'franco-allemande' => 'FRANCE_GERMANY',
      'franco-espagnole' => 'FRANCE_SPAIN',
      'franco-italienne' => 'FRANCE_ITALY',
      'franco-suisse' => 'FRANCE_SWITZERLAND',
      'franco-luxembourgeoise' => 'FRANCE_LUXEMBOURG',
      'franco-belge' => 'BELGIUM_FRANCE'
    }.freeze

    def url
      "https://www.sia.aviation-civile.gouv.fr/dvd/eAIP_%s/FRANCE/AIRAC-%s/html/eAIP/FR-%s-fr-FR.html" % [
        @airac.strftime('%d_%^b_%Y'),   # 04_JAN_2018
        @airac,                         # 2018-01-04
        @aip                            # ENR-5.1
      ]
    end

    def convert!
      html.css('tbody:has(tr[id^=mid])').each do |tbody|
        airspace = nil
        tbody.css('tr').each_with_index do |tr, index|
          if tr.attr(:class) =~ /keep-with-next-row/
            airspace = airspace_from tr
          else
            begin
              tds = tr.css('td')
              airspace.geometry = geometry_from tds[0]
              airspace.vertical_limits = vertical_limits_from tds[1]
              airspace.schedule = schedule_from tds[2]
              airspace.remarks = remarks_from(tds[2], tds[3], tds[4])
              fail "airspace `#{airspace.name}' is not complete" unless airspace.complete?
              aixm << airspace
              break if index / 2 > @limit
            rescue => exception
              warn("WARNING: error parsing airspace `#{airspace.name}': #{exception.message}", binding)
            end
          end
        end
      end
      true
    end

    private

    def airspace_from(tr)
      spans = tr.css(:span)
      AIXM::Feature::Airspace.new(
        name: [spans[1], spans[2], spans[3], spans[5].text.blank_to_nil].compact.join(' '),
        short_name: [spans[1], spans[2], spans[3]].compact.join(' '),
        type: TYPES.fetch(spans[2].text)
      )
    end

    def geometry_from(td)
      AIXM::Geometry.new.tap do |geometry|
        buffer = {}
        td.text.gsub(/\s+/, ' ').strip.split(/ - /).append('end').each do |element|
          case element
          when /frontière (.+)/i
            geometry << AIXM::Horizontal::Border.new(
              xy: buffer.delete(:xy),
              name: BORDERS.fetch($1)
            )
          when /arc (anti-)?horaire .+ sur (\S+) , (\S+)/i
            geometry << AIXM::Horizontal::Arc.new(
              xy: buffer.delete(:xy),
              center_xy: AIXM::XY.new(lat: $2, long: $3),
              clockwise: $1.nil?
            )
          when /cercle de ([\d\.]+) (NM|km|m) .+ sur (\S+) , (\S+)/i
            geometry << AIXM::Horizontal::Circle.new(
              center_xy: AIXM::XY.new(lat: $3, long: $4),
              radius: $1.to_f.to_km(from: $2).round(3)
            )
          when /end|(\S+) , (\S+)/
            geometry << AIXM::Horizontal::Point.new(xy: buffer[:xy]) if buffer.has_key?(:xy)
            buffer[:xy] = AIXM::XY.new(lat: $1, long: $2) if $1
          else
            fail "geometry `#{element}' not recognized"
          end
        end
      end
    end

    def vertical_limits_from(td)
      above, below = td.text.gsub(/ /, '').split(/\n+/).select(&:blank_to_nil).split(/---+/)
      above.reverse!
      AIXM::Vertical::Limits.new(
        max_z: z_from(below[1]),
        upper_z: z_from(above[0]),
        lower_z: z_from(below[0]),
        min_z: z_from(below[1])
      )
    end

    def z_from(limit)
      case limit
        when nil then nil
        when 'SFC' then AIXM::GROUND
        when 'UNL' then AIXM::UNLIMITED
        when /(\d+)ftASFC/ then AIXM::Z.new(alt: $1.to_i, code: :QFE)
        when /(\d+)ftAMSL/ then AIXM::Z.new(alt: $1.to_i, code: :QNH)
        when /FL(\d+)/ then AIXM::Z.new(alt: $1.to_i, code: :QNE)
        else fail "z `#{limit}' not recognized"
      end
    end

    def schedule_from(td)
      AIXM::H24 if td.text.gsub(/\W/, '') == 'H24'
    end

    def remarks_from(*parts)
      part_titles = ['SCHEDULE', 'RESTRICTION', 'AUTHORITY/CONDITIONS']
      [].tap do |remarks|
        parts.each.with_index do |part, index|
          if part = part.text.gsub(/ +/, ' ').gsub(/(\n ?)+/, "\n").strip.blank_to_nil
            unless index.zero? && part == 'H24'
              remarks << "#{part_titles[index]}:\n#{part}"
            end
          end
        end
      end.join("\n\n")
    end

  end
end
