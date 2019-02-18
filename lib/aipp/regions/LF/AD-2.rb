module AIPP
  module LF

    # Airports, CTR, AD navigational aids
    class AD2 < AIP
      using AIXM::Refinements

      # Map source types to type and optional local type
      SOURCE_TYPES = {
        'CTR' => { type: 'CTR' },
        'RMZ' => { type: 'RAS', local_type: 'RMZ' },
        'TMZ' => { type: 'RAS', local_type: 'TMZ' },
        'RMZ-TMZ' => { type: 'RAS', local_type: 'RMZ-TMZ' }
      }.freeze

      # Airports without VAC (e.g. military installations)
      NO_VAC = %w(LFOA LFBC LFQE LFOE LFSX LFBM LFSO LFMO LFQP LFSI LFKS LFPV).freeze

      # Airports without VFR reporting points
      # TODO: designated points on map but no list (LFLD LFSN LFBS) or no AD info (LFRL)
      NO_DESIGNATED_POINTS = %w(LFAB LFAC LFAV LFAY LFBK LFBN LFBX LFCC LFCI LFCK LFCY LFDH LFDJ LFDN LFEC LFEY LFGA LFHP LFHV LFHY LFJR LFJY LFLA LFLH LFLO LFLV LFLW LFMQ LFMQ LFNB LFOH LFOQ LFOU LFOV LFOZ LFPO LFQA LFQB LFQG LFQM LFRC LFRI LFRM LFRT LFRU LFSD LFSG LFSM LFLD LFSN LFBS LFRL).freeze

      # Map synonyms for +correlate+
      SYNONYMS = [
        'nord', 'north',
        'est', 'east',
        'sud', 'south',
        'ouest', 'west',
        'inst', 'instruction',
        'junction', 'intersection',
        'harbour', 'port',
        'mouth', 'embouchure',
        'tower', 'chateau'
      ].freeze

      def parse
        cache.airport_ids = []
        index = read("AD-0.6")   # index for AD-2.xxxx files
        index.css('#AD-0\.6\.eAIP > .toc-block:nth-of-type(3) .toc-block a').each do |a|
          @id = a.attribute('href').value[-4,4]
          begin
            aip_file = "AD-2.#{@id}"
            cache.airport_ids << @id
            html = read(aip_file)
            # Airport
            @remarks = []
            airport = AIXM.airport(
              source: source_for(html.css('tr[id*="CODE_ICAO"]').first, aip_file: aip_file),
              organisation: organisation_lf,   # TODO: not yet implemented
              id: @id,
              name: html.css('tr[id*="CODE_ICAO"] td span:nth-of-type(2)').text.uptrans,
              xy: xy_from(html.css('#AD-2\.2-Position_Geo_Arp td:nth-of-type(3)').text)
            ).tap do |airport|
              airport.z = elevation_from(html.css('#AD-2\.2-Altitude_Reference td:nth-of-type(3)').text)
              airport.declination = declination_from(html.css('#AD-2\.2-Declinaison_Magnetique td:nth-of-type(3)').text)
              airport.transition_z = AIXM.z(5000, :qnh)   # TODO: default - exceptions may exist
              airport.timetable = timetable_from(html.css('#AD-2\.3-Gestionnaire_AD td:nth-of-type(3)').text)
            end
            runways_from(html.css('div[id*="-AD-2\.12"] tbody'), airport).each { |r| airport.add_runway(r) if r }
            helipads_from(html.css('div[id*="-AD-2\.16"] tbody')).each { |h| airport.add_helipad(h) if h }
            # TODO: airport.add_usage_limitation(UsageLimitation::TYPES)
            text = html.css('#AD-2\.2-Observations td:nth-of-type(3)').text
            airport.remarks = ([remarks_from(text)] + @remarks).compact.join("\n\n").blank_to_nil
            write airport
            # Airspaces
            airspaces_from(html.css('div[id*="-AD-2\.17"] tbody')).each { |a| write a }
            # Navigational aids
            # TODO
            # Designated points
            unless NO_VAC.include?(@id) || NO_DESIGNATED_POINTS.include?(@id)
              text = read("VAC.#{@id}")
              designated_points_from(text, airport).tap do |designated_points|
                fix_designated_point_remarks(designated_points)
                designated_points.each { |dp| write dp }
#               debug(designated_points)
              end
            end
          rescue => error
            warn("error parsing airport #{@id}: #{error.message}", pry: error)
          end
        end
      end

      private

      def elevation_from(text)
        value, unit = text.strip.split
        AIXM.z(AIXM.d(value.to_i, unit).to_ft.dist, :qnh)
      end

      def declination_from(text)
        value, direction = text.strip.split('°')
        value = value.to_f * (direction == 'W' ? -1 : 1)
      end

      def remarks_from(text)
        text.sub(/NIL|\(\*\)\s+/, '').strip.gsub(/(\s)\s+/, '\1').blank_to_nil
      end

      def runways_from(tbody, airport)
        directions_map = tbody.css('tr[id*="TXT_DESIG"]').map do |tr|
          [AIXM.a(tr.css('td:first-of-type').text.strip), tr]
        end.to_h
        remarks_map = tbody.css('tr[id*="TXT_RMK_NAT"]').map do |tr|
          [tr.text.strip[/\A\((\d+)\)/, 1].to_i, tr.css('span')]
        end.to_h
        directions = directions_map.keys
        grouped_directions = directions.map do |direction|
          inverted_direction = direction.invert
          if directions.include? inverted_direction
            [direction, inverted_direction].map(&:to_s).sort.join('/')
          else
            direction.to_s
          end
        end.uniq
        grouped_directions.map do |runway_name|
          AIXM.runway(name: runway_name).tap do |runway|
            runway.airport = airport   # early assignment for callbacks
            %i(forth back).each do |direction_attr|
              if direction = runway.send(direction_attr)
                tr = directions_map[direction.name]
                if direction_attr == :forth
                  length, width = tr.css('td:nth-of-type(3)').text.strip.split('x')
                  runway.length = AIXM.d(length.strip.to_i, :m)
                  runway.width = AIXM.d(width.strip.to_i, :m)
                  text = tr.css('td:nth-of-type(5)').text.strip.split(%r<\W+/\W+>).last
                  runway.surface.composition = COMPOSITIONS.fetch(text)[:composition]
                  runway.surface.preparation = COMPOSITIONS.fetch(text)[:preparation]
                  if (text = tr.css('td:nth-of-type(4)').text).match?(AIXM::PCN_RE)
                    runway.surface.pcn = text
                  end
                end
                text = tr.css('td:nth-of-type(6)').text.strip
                direction.xy = (xy_from(text) unless text.match?(/\A(\(.*)?\z/m))
                if (text = tr.css('td:nth-of-type(7)').text.strip[/thr:\s+(\d+\s+\w+)/i, 1]).present?
                  direction.z = elevation_from(text)
                end
                if (text = tr.css('td:nth-of-type(2)').text.strip.sub(/\A(\d+).*$/m, '\1')).present?
                  direction.geographic_orientation = AIXM.a(text.to_i)
                end
                if (text = tr.css('td:nth-of-type(6)').text[/\((.+)\)/m, 1]).present?
                  direction.displaced_threshold = xy_from(text)
                end
                if (text = tr.css('td:nth-of-type(10)').text.strip[/\A\((\d+)\)/, 1]).present?
                  direction.remarks = remarks_from(remarks_map.fetch(text.to_i).text)
                end
              end
            end
          end
        end
      end

      def helipads_from(tbody)
        text_fr = tbody.css('td:nth-of-type(3)').text.compact
        text_en = tbody.css('td:nth-of-type(4)').text.compact
        case text_fr
        when /NIL/, /\A\W*\z/
          []
        when /instructions?\s+twr/i
          @remarks << "HELICOPTER:\nSur instructions TWR.\nOn TWR clearance."
          []
        when AIXM::DMS_RE
          text_fr.scan(AIXM::DMS_RE).each_slice(2).with_index(1).map do |(lat, long), index|
            AIXM.helipad(name: "H#{index}").tap do |helipad|
              helipad.xy = AIXM.xy(lat: lat.first, long: long.first)
            end
          end
        else
          @remarks << ['HELICOPTER:', text_fr.blank_to_nil, text_en.blank_to_nil].compact.join("\n")
          []
        end
      end

=begin
      def usage_limitations_from(text)
        case text
        when /interdit +aux +planeurs/i 2.22
        when /ferme +a +la +cap/i   # 2.20
          # MIL
        when /vfr/   # 2.2-7
        when /ifr/   # 2.2-7
        when /???/   # not-scheduled (lfnt)
      end
=end

      def airspaces_from(tbody)
        return [] if tbody.text.blank?
        airspace = nil
        tbody.css('tr').to_enum.with_object([]) do |tr, array|
          if tr.attr(:class) =~ /keep-with-next-row/
            airspace = airspace_from cleanup(node: tr)
          else
            tds = cleanup(node: tr).css('td')
            airspace.geometry = geometry_from tds[0].text
            fail("geometry is not closed") unless airspace.geometry.closed?
            airspace.layers << layer_from(tds[2].text, tds[1].text.strip)
            airspace.layers.first.timetable = timetable_from tds[4].text
            airspace.layers.first.remarks = remarks_from(tds[4].text)
            array << airspace
          end
        end
      end

      def airspace_from(tr)
        spans = tr.css(:span)
        source_type = spans[1].text.blank_to_nil
        fail "unknown type `#{source_type}'" unless SOURCE_TYPES.has_key? source_type
        AIXM.airspace(
          name: [spans[2].text, anglicise(name: spans[3]&.text)].compact.join(' '),
          type: SOURCE_TYPES.dig(source_type, :type),
          local_type: SOURCE_TYPES.dig(source_type, :local_type)
        ).tap do |airspace|
          airspace.source = source_for(tr)
        end
      end

      def designated_points_from(text, airport, recursive=false)
        from = (text =~ /^.*?coordinates.*?names?/i)
        return [] if recursive && !from
        warn("no designated points section begin found for #{@id}", pry: binding) unless from
        to = from + (text.from(from) =~ /\n\s*\n\s*\n|^.*(?:ifr|vfr|ad\s*equipment|special\s*activities|training\s*flights)/i)
        warn("no designated points section end found for #{@id}", pry: binding) unless to
        buffer = {}
        lines = text[from..to].gsub(/\u2190/, '').lines.drop(1)
        lines.append("\e").each.with_object([]) do |line, designated_points|
          has_id = $1 if line.sub!(/^\s{,20}([A-Z][A-Z\d ]{1,3})(?=\W)/, '')
          has_xy = line.match?(AIXM::DMS_RE)
          if (line == "\e" || has_id || has_xy) && buffer[:id] && buffer[:xy]&.size == 2
            designated_points << designated_point_from(buffer, airport)
            buffer.clear
          end
          if has_xy
            2.times { (buffer[:xy] ||= []) << $1 if line.sub!(AIXM::DMS_RE, '') }
            buffer[:xy]&.compact!
            line.remove!(/\d{3,4}\D.+?MTG/)   # remove extra columns (e.g. LFML)
            line.remove!(/[\s#{AIXM::MIN}#{AIXM::SEC}]*[-\u2013]/)   # remove dash between coordinates
          end
          buffer[:id] = has_id if has_id
          buffer[:remarks] = [buffer[:remarks], line].join("\n")
        end + designated_points_from(text.from(to), airport, true)
      end

      def designated_point_from(buffer, airport)
        buffer[:remarks].gsub!(/ {20}/, "\n")   # recognize empty column space
        buffer[:remarks].remove!(/\(\d+\)/)   # remove footnotes
        buffer[:remarks] = buffer[:remarks].unglue   # separate glued words
        AIXM.designated_point(
          type: :vfr_mandatory_reporting_point,
          id: buffer[:id].remove(/\W/),
          xy: AIXM.xy(lat: buffer[:xy].first, long: buffer[:xy].last)
        ).tap do |designated_point|
          designated_point.airport = airport
          designated_point.remarks = buffer[:remarks].remove(/\e/).compact.blank_to_nil
        end
      end

      # Assign scattered similar remarks to one and the same designated point
      def fix_designated_point_remarks(designated_points)
        one = nil
        designated_points.map do |two|
          if one
            one_lines, two_lines = one.remarks&.lines, two.remarks&.lines
            if one_lines && two_lines
              if one_lines.count > 1 && (line = one_lines.last) !~ %r(\s/\s)
                # Move up
                if line.correlate(remainder = one_lines[0..-2].join, SYNONYMS) < line.correlate(two.remarks)
                  two.remarks = [line, two.remarks].join("\n").compact
                  one.remarks = remainder.compact
                end
              elsif two_lines.count > 1 && (line = two_lines.first) !~ %r(\s/\s)
                # Move down
                line = two_lines.first
                if line.correlate(remainder = two_lines[1..-1].join, SYNONYMS) < line.correlate(one.remarks)
                  one.remarks = [one.remarks, line].join("\n").compact
                  two.remarks = remainder.compact
                end
              end
            end
          end
          one = two
        end.map do |designated_point|
          designated_point.remarks = designated_point.remarks&.cleanup.blank_to_nil
        end
      end

#     def debug(dp)
#       f = "/Users/sschwyn/Desktop/okay/#{@id}.txt"
#       result = "\n--- #{@id} ---\n\n".red
#       dp.each do |d|
#         result += d.id.red + "\t#{d.xy.lat} - #{d.xy.long}\n"
#         result += "#{d.remarks}\n\n".blue
#       end
#       result += "#{dp.count} point(s) for #{@id}".red
#       unless File.exist?(f) && result == File.read(f)
#         puts result
#         gets
#         puts "\e[H\e[2J"
#       end
#       File.write(f, result)
#     end

      patch AIXM::Component::Runway::Direction, :xy do |object, value|
        throw :abort unless value.nil?
        @fixtures ||= YAML.load_file(Pathname(__FILE__).dirname.join('AD-2.yml'))
        airport_id, direction_name = object.send(:runway).airport.id, object.name.to_s
        throw :abort if (xy = @fixtures.dig('runways', airport_id, direction_name, 'xy')).nil?
        lat, long = xy.split(/\s+/)
        AIXM.xy(lat: lat, long: long)
      end

      patch AIXM::Feature::NavigationalAid, :remarks do |object, value|
        @fixtures ||= YAML.load_file(Pathname(__FILE__).dirname.join('AD-2.yml'))
        airport_id, designated_point_id = object.airport.id, object.id
        @fixtures.dig('designated_points', airport_id, designated_point_id, 'remarks') || throw(:abort)
      end

    end
  end
end
