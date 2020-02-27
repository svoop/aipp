module AIPP
  module LF

    # Aerodromes
    class AD13 < AIP

      include AIPP::LF::Helpers::Base

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
      }.freeze

      PURPOSES = {
        "s" => :scheduled,
        "ns" => :not_scheduled,
        "p" =>  :private
      }.freeze

      def parse
        ad2_exists = false
        tbody = prepare(html: read).css('tbody').first   # skip altiports
        tbody.css('tr').to_enum.with_index(1).each do |tr, index|
          if tr.attr(:id).match?(/-TXT_NAME-/)
            add @airport if @airport && !ad2_exists
            @airport = airport_from tr
            verbose_info "Parsing #{@airport.id}"
            ad2_exists = false
            if airport = find_by(:airport, id: @airport.id).first
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
        @airport.add_usage_limitation(type: limitation) do |l|
          (%w(s ns p) & raw_conditions).each do |raw_purpose|
            l.add_condition do |c|
              c.realm = raw_limitation.match?(/milit/) ? :military : :civilian
              if (%w(intl ntl) - raw_conditions).empty?
                c.origin = :any
              else
                c.origin = :national if raw_conditions.include?('ntl')
                c.origin = :international if raw_conditions.include?('intl')
              end
              if (%w(ifr vfr) - raw_conditions).empty?
                c.rule = :ifr_and_vfr
              else
                c.rule = :ifr if raw_conditions.include?('ifr')
                c.rule = :vfr if raw_conditions.include?('vfr')
              end
              c.purpose = PURPOSES[raw_purpose]
            end
          end
          l.remarks = "Usage restreint (voir VAC) / restricted use (see VAC)" if raw_limitation.match?(/usa.+restr/)
          l.remarks = "Propriété privée / privately owned" if raw_limitation.match?(/priv/)
        end
      end

      def runway_from(tr)
        tds = tr.css('td')
        AIXM.runway(
          name: tds[0].text.strip.split.join('/')
        ).tap do |runway|
          @runway = runway   # TODO: needed for now for surface composition patches to work
          bidirectional = runway.name.include? '/'
          runway.length = AIXM.d(tds[1].css('span[id$="VAL_LEN"]').text.to_i, :m)
          runway.width = AIXM.d(tds[1].css('span[id$="VAL_WID"]').text.to_i, :m)
          unless (text = tds[1].css('span[id*="SURFACE"]').text.compact).blank?
            surface = SURFACES.metch(text)
            runway.surface.composition = surface[:composition]
            runway.surface.preparation = surface[:preparation]
            runway.surface.remarks = surface[:remarks]
          end
          runway.remarks = tds[7].text.cleanup.blank_to_nil
          values = tds[2].text.remove('°').strip.split
          runway.forth.geographic_orientation = AIXM.a(values.first.to_i)
          runway.back.geographic_orientation = AIXM.a(values.last.to_i) if bidirectional
          parts = tds[3].text.strip.split(/\n\s+\n\s+/, 2)
          runway.forth.xy = (xy_from(parts[0]) unless parts[0].blank?)
          runway.back.xy = (xy_from(parts[1]) unless parts[1].blank?) if bidirectional
          values = tds[4].text.strip.split
          runway.forth.z = AIXM.z(values.first.to_i, :qnh)
          runway.back.z = AIXM.z(values.last.to_i, :qnh) if bidirectional
          displaced_thresholds = displaced_thresholds_from(tds[5])
          runway.forth.displaced_threshold = displaced_thresholds.first
          runway.back.displaced_threshold = displaced_thresholds.last if bidirectional
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
        airport_id = parser.instance_variable_get(:@airport).id
        runway_name = object.name.to_s
        throw :abort if (width = parser.fixture.dig('runways', airport_id, runway_name, 'width')).nil?
        AIXM.d(width.to_i, :m)
      end

      patch AIXM::Component::Runway::Direction, :xy do |parser, object, value|
        throw :abort unless value.nil?
        airport_id = parser.instance_variable_get(:@airport).id
        direction_name = object.name.to_s
        throw :abort if (xy = parser.fixture.dig('runways', airport_id, direction_name, 'xy')).nil?
        lat, long = xy.split(/\s+/)
        AIXM.xy(lat: lat, long: long)
      end

      patch AIXM::Component::Surface, :composition do |parser, object, value|
        throw :abort unless value.blank?
        airport_id = parser.instance_variable_get(:@airport).id
        runway_name = parser.instance_variable_get(:@runway).name
        throw :abort if (composition = parser.fixture.dig('runways', airport_id, runway_name, 'composition')).nil?
        composition
      end

    end
  end
end
