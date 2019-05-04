module AIPP
  module LF

    # Aerodromes
    class AD13 < AIP

      include AIPP::LF::Helpers::Common

      DEPENDS = %w(AD-2)

      # Map names of id-less airports to unofficial ids
      ID_LESS_AIRPORTS = {
        "ALBE" => 'LF9001',
        "BEAUMONT DE LOMAGNE" => 'LF9002',
        "BERDOUES" => 'LF9003',
        "BOULOC" => 'LF9004',
        "BUXEUIL ST REMY / CREUSE" => 'LF9005',
        "CALVIAC" => 'LF9006',
        "CAYLUS" => 'LF9007',
        "CORBONOD" => 'LF9008',
        "L'ISLE EN DODON" => 'LF9009',
        "LACAVE LE FRAU" => 'LF9010',
        "LUCON CHASNAIS" => 'LF9011',
        "PEYRELEVADE" => 'LF9012',
        "SAINT CYR LA CAMPAGNE" => 'LF9013',
        "SEPTFONDS" => 'LF9014',
        "TALMONT VENDEE AIR PARK" => 'LF9015'
      }

      def parse
        ad2_exists = false
        tbody = prepare(html: read).css('tbody').first   # skip altiports
        tbody.css('tr').to_enum.with_index(1).each do |tr, index|
          if tr.attr(:id).match?(/-TXT_NAME-/)
            add @airport if @airport && !ad2_exists
            @airport = airport_from tr
            verbose_info "Parsing #{@airport.id}"
            ad2_exists = false
            if airport = select(:airport, id: @airport.id).first
              ad2_exists = true
              @airport = airport
            end
            add_usage_limitations_from tr
            next
          end
          @airport.add_runway(runway_from(tr)) unless ad2_exists
        rescue => error
          warn("error parsing #{@airport.id} at ##{index}: #{error.message}", pry: error)
        end
        add @airport if @airport && !ad2_exists
      end

      private

      def airport_from(tr)
        tds = tr.css('td')
        id = tds[0].text.strip.blank_to_nil || ID_LESS_AIRPORTS.fetch(tds[1].text.strip)
        AIXM.airport(
          source: source(position: tr.line),
          organisation: organisation_lf,   # TODO: not yet implemented
          id: id,
          name: tds[1].text.strip,
          xy: xy_from(tds[3].text)
        ).tap do |airport|
          airport.z = AIXM.z(tds[4].text.strip.to_i, :qnh)
          airport.declination = tds[2].text.remove('°').strip.to_f
#         airport.transition_z = AIXM.z(5000, :qnh)   # TODO: default - exceptions exist
        end
      end

      def add_usage_limitations_from(tr)
        raw_limitation = tr.css('td:nth-of-type(8)').text.cleanup.downcase
        raw_conditions = tr.css('td:nth-of-type(6)').text.cleanup.downcase.split(%r([\s/]+))
        limitation = case raw_limitation
          when /ouv.+cap|milit/ then :permitted
          when /usa.+restr|priv/ then :reservation_required
        end
        @airport.add_usage_limitation(limitation) do |l|
          l.add_condition do |c|
            c.realm = :military if raw_limitation.match?(/milit/)
            c.origin = :national if raw_conditions.include?('ntl')
            c.origin = :international if raw_conditions.include?('intl')
            c.rule = :ifr if raw_conditions.include?('ifr')
            c.rule = :vfr if raw_conditions.include?('vfr')
            c.purpose = :scheduled if raw_conditions.include?('s')
            c.purpose = :not_scheduled if raw_conditions.include?('ns')
            c.purpose = :private if raw_conditions.include?('p')
          end
          l.remarks = "Usage restreint (voir VAC) / restricted use (see VAC)" if raw_limitation.match?(/usa.+restr/)
          l.remarks = "Propriété privée / privately owned" if raw_limitation.match?(/priv/)
        end
      end

      def runway_from(tr)
        tds = tr.css('td')
        surface = tds[1].css('span[id*="SURFACE"]').text
        AIXM.runway(
          name: tds[0].text.strip.split.join('/')
        ).tap do |runway|
          @runway = runway   # TODO: needed for now for surface composition patches to work
          runway.length = AIXM.d(tds[1].css('span[id$="VAL_LEN"]').text.to_i, :m)
          runway.width = AIXM.d(tds[1].css('span[id$="VAL_WID"]').text.to_i, :m)
          runway.surface.composition = (COMPOSITIONS.fetch(surface)[:composition] unless surface.blank?)
          runway.surface.preparation = (COMPOSITIONS.fetch(surface)[:preparation] unless surface.blank?)
          runway.remarks = tds[7].text.cleanup.blank_to_nil
          values = tds[2].text.remove('°').strip.split
          runway.forth.geographic_orientation = AIXM.a(values.first.to_i)
          runway.back.geographic_orientation = AIXM.a(values.last.to_i)
          parts = tds[3].text.strip.split(/\n\s+\n\s+/)
          runway.forth.xy = (xy_from(parts[0]) unless parts[0].blank?)
          runway.back.xy = (xy_from(parts[1]) unless parts[1].blank?)
          values = tds[4].text.strip.split
          runway.forth.z = AIXM.z(values.first.to_i, :qnh)
          runway.back.z = AIXM.z(values.last.to_i, :qnh)
          displaced_thresholds = displaced_thresholds_from(tds[5])
          runway.forth.displaced_threshold = displaced_thresholds.first
          runway.back.displaced_threshold = displaced_thresholds.last
        end
      end

      def displaced_thresholds_from(td)
        values = td.text.strip.split
        case values.count
          when 1 then []
          when 2 then [AIXM.xy(lat: values[0], long: values[1]), nil]
          when 3 then [nil, AIXM.xy(lat: values[1], long: values[2])]
          when 4 then [AIXM.xy(lat: values[0], long: values[1]), AIXM.xy(lat: values[2], long: values[3])]
          else fail "cannot parse displaced thresholds"
        end
      end

      patch AIXM::Component::Runway, :width do |parser, object, value|
        throw :abort unless value.zero?
        @fixtures ||= YAML.load_file(Pathname(__FILE__).dirname.join('AD-1.3.yml'))
        airport_id = parser.instance_variable_get(:@airport).id
        runway_name = object.name.to_s
        throw :abort if (width = @fixtures.dig('runways', airport_id, runway_name, 'width')).nil?
        AIXM.d(width.to_i, :m)
      end

      patch AIXM::Component::Runway::Direction, :xy do |parser, object, value|
        throw :abort unless value.nil?
        @fixtures ||= YAML.load_file(Pathname(__FILE__).dirname.join('AD-1.3.yml'))
        airport_id = parser.instance_variable_get(:@airport).id
        direction_name = object.name.to_s
        throw :abort if (xy = @fixtures.dig('runways', airport_id, direction_name, 'xy')).nil?
        lat, long = xy.split(/\s+/)
        AIXM.xy(lat: lat, long: long)
      end

      patch AIXM::Component::Surface, :composition do |parser, object, value|
        throw :abort unless value.blank?
        @fixtures ||= YAML.load_file(Pathname(__FILE__).dirname.join('AD-1.3.yml'))
        airport_id = parser.instance_variable_get(:@airport).id
        runway_name = parser.instance_variable_get(:@runway).name
        throw :abort if (composition = @fixtures.dig('runways', airport_id, runway_name, 'composition')).nil?
        composition
      end

    end
  end
end
