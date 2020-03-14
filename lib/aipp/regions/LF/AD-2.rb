module AIPP
  module LF

    # Airports (IFR capable) and their CTR, AD navigational aids etc
    class AD2 < AIP

      include AIPP::LF::Helpers::Base
      include AIPP::LF::Helpers::NavigationalAid
      include AIPP::LF::Helpers::RadioAD
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
      NO_DESIGNATED_POINTS = %w(LFAB LFAC LFAV LFAY LFBK LFBN LFBX LFCC LFCI LFCK LFCY LFDH LFDJ LFDN LFEC LFFK LFEV LFEY LFGA LFHP LFHV LFHY LFJR LFJY LFLA LFLH LFLO LFLV LFLW LFMQ LFMQ LFNB LFOH LFOQ LFOU LFOV LFOZ LFPO LFQA LFQB LFQG LFQM LFRC LFRI LFRM LFRT LFRU LFSD LFSG LFSM LFLD LFSN LFBS LFRL).freeze

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
        index_html = prepare(html: read("AD-0.6"))   # index for AD-2.xxxx files
        index_html.css('#AD-0\.6\.eAIP > .toc-block:nth-of-type(3) .toc-block a').each do |a|
          @id = a.attribute('href').value[-4,4]
          begin
            aip_file = "AD-2.#{@id}"
            html = prepare(html: read(aip_file))
            # Airport
            @remarks = []
            @airport = AIXM.airport(
              source: source(position: html.css('tr[id*="CODE_ICAO"]').first.line, aip_file: aip_file),
              organisation: organisation_lf,   # TODO: not yet implemented
              id: @id,
              name: html.css('tr[id*="CODE_ICAO"] td span:nth-of-type(2)').text.strip.uptrans,
              xy: xy_from(html.css('#AD-2\.2-Position_Geo_Arp td:nth-of-type(3)').text)
            ).tap do |airport|
              airport.z = elevation_from(html.css('#AD-2\.2-Altitude_Reference td:nth-of-type(3)').text)
              airport.declination = declination_from(html.css('#AD-2\.2-Declinaison_Magnetique td:nth-of-type(3)').text)
  #           airport.transition_z = AIXM.z(5000, :qnh)   # TODO: default - exceptions may exist
              airport.timetable = timetable_from!(html.css('#AD-2\.3-Gestionnaire_AD td:nth-of-type(3)').text)
            end
            runways_from(html.css('div[id*="-AD-2\.12"] tbody')).each { @airport.add_runway(_1) if _1 }
            helipads_from(html.css('div[id*="-AD-2\.16"] tbody')).each { @airport.add_helipad(_1) if _1 }
            text = html.css('#AD-2\.2-Observations td:nth-of-type(3)').text
            @airport.remarks = ([remarks_from(text)] + @remarks).compact.join("\n\n").blank_to_nil
            add @airport
            # Airspaces
            airspaces_from(html.css('div[id*="-AD-2\.17"] tbody')).
              reject { aixm.features.find_by(_1.class, type: _1.type, id: _1.id).any? }.
              each(&method(:add))
            # Radio
            trs = html.css('div[id*="-AD-2\.18"] tbody tr')
            addresses_from(trs).each { @airport.add_address(_1) }
            units_from(trs, airport: @airport).each(&method(:add))
            # Navigational aids
            navigational_aids_from(html.css('div[id*="-AD-2\.19"] tbody')).
              reject { aixm.features.find_by(_1.class, id: _1.id, xy: _1.xy).any? }.
              each(&method(:add))
            # Designated points
            unless NO_VAC.include?(@id) || NO_DESIGNATED_POINTS.include?(@id)
              pdf = read("VAC-#{@id}")
              designated_points_from(pdf).tap do |designated_points|
                fix_designated_point_remarks(designated_points)
#               debug(designated_points)
                designated_points.
                  uniq(&:to_uid).
                  reject { aixm.features.find_by(_1.class, id: _1.id, xy: _1.xy).any? }.
                  each(&method(:add))
              end
            end
          rescue => error
            warn("error parsing airport #{@id}: #{error.message}", pry: error)
          end
        end
      end

      private

      def declination_from(text)
        value, direction = text.strip.split('°')
        value = value.to_f * (direction == 'W' ? -1 : 1)
      end

      def remarks_from(text)
        text.sub(/NIL|\(\*\)\s+/, '').strip.gsub(/(\s)\s+/, '\1').blank_to_nil
      end

      def runways_from(tbody)
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
            %i(forth back).each do |direction_attr|
              if direction = runway.send(direction_attr)
                tr = directions_map[direction.name]
                if direction_attr == :forth
                  length, width = tr.css('td:nth-of-type(3)').text.strip.split('x')
                  runway.length = AIXM.d(length.strip.to_i, :m)
                  runway.width = AIXM.d(width.strip.to_i, :m)
                  unless (text = tr.css('td:nth-of-type(5)').text.strip.split(%r<\W+/\W+>).first.compact).blank?
                    surface = SURFACES.metch(text)
                    runway.surface.composition = surface[:composition]
                    runway.surface.preparation = surface[:preparation]
                    runway.surface.remarks = surface[:remarks]
                  end
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
            AIXM.helipad(
              name: "H#{index}",
              xy: AIXM.xy(lat: lat.first, long: long.first)
            )
          end
        else
          @remarks << ['HELICOPTER:', text_fr.blank_to_nil, text_en.blank_to_nil].compact.join("\n")
          []
        end
      end

      def airspaces_from(tbody)
        return [] if tbody.text.blank?
        airspace = nil
        tbody.css('tr').to_enum.with_object([]) do |tr, array|
          if tr.attr(:class) =~ /keep-with-next-row/
            airspace = airspace_from tr
          else
            tds = tr.css('td')
            airspace.geometry = geometry_from tds[0].text
            fail("geometry is not closed") unless airspace.geometry.closed?
            airspace.add_layer layer_from(tds[2].text, tds[1].text.strip)
            airspace.layers.first.timetable = timetable_from! tds[4].text
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
          airspace.source = source(position: tr.line)
        end
      end

      def navigational_aids_from(tbody)
        tbody.css('tr').to_enum.with_object([]) do |tr, array|
          tds = tr.css('td')
          array << navigational_aid_from(
            {
              name: OpenStruct.new(text: @airport.name),   # simulate td
              type: tds[0],
              id: tds[1],
              f: tds[2],
              schedule: tds[3],
              xy: tds[4],
              z: tds[5]
            },
            source: source(position: tr.line),
            sections: {
              range: tds[6],
              situation: tds[8]
            }
          )
        end.compact
      end

      def designated_points_from(pdf, recursive=false)
        from = (pdf.text =~ /^(.*?coordinates.*?names?)/i)
        return [] if recursive && !from
        warn("no designated points section begin found for #{@id}", pry: binding) unless from
        from += $1.length
        to = from + (pdf.text.from(from) =~ /\n\s*\n\s*\n|^.*(?:ifr|vfr|ad\s*equipment|special\s*activities|training\s*flights|mto\s*minima)/i)
        warn("no designated points section end found for #{@id}", pry: binding) unless to
        from, to = from + pdf.range.min, to + pdf.range.min   # offset when recursive
        buffer = {}
        pdf.from(from).to(to).each_line.with_object([]) do |(line, page, last), designated_points|
          line.remove!(/\u2190/)   # remove arrow symbols
          has_id = $1 if line.sub!(/^\s{,20}([A-Z][A-Z\d ]{1,3})(?=\W)/, '')
          has_xy = line.match?(AIXM::DMS_RE)
          designated_points << designated_point_from(buffer, pdf) if has_id || has_xy
          if has_xy
            2.times { (buffer[:xy] ||= []) << $1 if line.sub!(AIXM::DMS_RE, '') }
            buffer[:xy]&.compact!
            line.remove!(/\d{3,4}\D.+?MTG/)   # remove extra columns (e.g. LFML)
            line.remove!(/[\s#{AIXM::MIN}#{AIXM::SEC}]*[-\u2013]/)   # remove dash between coordinates
          end
          buffer[:page] = page
          buffer[:id] = has_id if has_id
          buffer[:remarks] = [buffer[:remarks], line].join("\n")
          designated_points << designated_point_from(buffer, pdf) if last
        end.compact + designated_points_from(pdf.from(to).to(:end), true)
      end

      def designated_point_from(buffer, pdf)
        if buffer[:id] && buffer[:xy]&.size == 2
          buffer[:remarks].gsub!(/ {20}/, "\n")   # recognize empty column space
          buffer[:remarks].remove!(/\(\d+\)/)   # remove footnotes
          buffer[:remarks] = buffer[:remarks].unglue   # separate glued words
          AIXM.designated_point(
            source: source(position: buffer[:page], aip_file: pdf.file.basename('.*').to_s),
            type: :vfr_mandatory_reporting_point,
            id: buffer[:id].remove(/\W/),
            xy: AIXM.xy(lat: buffer[:xy].first, long: buffer[:xy].last)
          ).tap do |designated_point|
            designated_point.airport = @airport
            designated_point.remarks = buffer[:remarks].compact.blank_to_nil
            buffer.clear
          end
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

      patch AIXM::Component::Runway::Direction, :xy do |parser, object, value|
        throw :abort unless value.nil?
        airport_id = parser.instance_variable_get(:@airport).id
        direction_name = object.name.to_s
        throw :abort if (xy = parser.fixture.dig('runways', airport_id, direction_name, 'xy')).nil?
        lat, long = xy.split(/\s+/)
        AIXM.xy(lat: lat, long: long)
      end

      patch AIXM::Feature::NavigationalAid, :remarks do |parser, object, value|
        throw :abort unless object.is_a? AIXM::Feature::NavigationalAid::DesignatedPoint
        airport_id, designated_point_id = object.airport.id, object.id
        parser.fixture.dig('designated_points', airport_id, designated_point_id, 'remarks') || throw(:abort)
      end

    end
  end
end
