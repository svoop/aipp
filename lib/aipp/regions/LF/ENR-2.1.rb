module AIPP
  module LF

    # FIR, TMA etc
    class ENR21 < AIP

      include AIPP::LF::Helpers::Base

      # Airspaces to be ignored
      NAME_BLACKLIST_RE = /deleg/i.freeze

      # Map source types to type and optional local type
      SOURCE_TYPES = {
        'FIR' => { type: 'FIR' },
        'UIR' => { type: 'UIR' },
        'UTA' => { type: 'UTA' },
        'CTA' => { type: 'CTA' },
        'LTA' => { type: 'CTA', local_type: 'LTA' },
        'TMA' => { type: 'TMA' },
        'SIV' => { type: 'SECTOR', local_type: 'SIV' }   # providing FIS
      }.freeze

      # Map airspace "<type> <name>" to location indicator
      LOCATION_INDICATORS = {
        'FIR BORDEAUX' => 'LFBB',
        'FIR BREST' => 'LFRR',
        'FIR MARSEILLE' => 'LFMM',
        'FIR PARIS' => 'LFFF',
        'FIR REIMS' => 'LFRR'
      }.freeze

      # Fix incomplete SIV service columns
      SERVICE_FIXES = {
        "IROISE INFO 135.825 / 119.575 (1)" => "APP IROISE\nIROISE INFO 135.825 / 119.575 (1)",
        "APP TOULOUSE\nTOULOUSE INFO" => "APP TOULOUSE\nTOULOUSE INFO 121.250"
      }.freeze

      def parse
        prepare(html: read).css('tbody').each do |tbody|
          airspace = nil
          tbody.css('tr').to_enum.with_index(1).each do |tr, index|
            if tr.attr(:id).match?(/--TXT_NAME/)
              if airspace
                if airspace.name.match? NAME_BLACKLIST_RE
                  verbose_info "Ignoring #{airspace.type} #{airspace.name}" unless airspace.type == :terminal_control_area
                else
                  add airspace
                end
              end
              airspace = airspace_from tr.css(:td).first
              verbose_info "Parsing #{airspace.type} #{airspace.name}" unless airspace.type == :terminal_control_area
              next
            end
            begin
              tds = tr.css('td')
              if airspace.type == :terminal_control_area && tds[0].text.blank_to_nil
                if airspace.layers.any?
                  if airspace.name.match? NAME_BLACKLIST_RE
                    verbose_info "Ignoring #{airspace.type} #{airspace.name}"
                  else
                    add airspace
                  end
                end
                airspace = airspace_from tds[0]
                verbose_info "Parsing #{airspace.type} #{airspace.name}"
              end
              if airspace
                remarks = tds[-1].text
                if tds[0].text.blank_to_nil
                  airspace.geometry = geometry_from tds[0].text
                  fail("geometry is not closed") unless airspace.geometry.closed?
                end
                layer = layer_from(tds[-3].text)
                layer.class = class_from(tds[1].text) if tds.count == 5
                layer.location_indicator = LOCATION_INDICATORS.fetch("#{airspace.type} #{airspace.name}", nil)
                if airspace.local_type == 'SIV'   # services parsed for SIV only
                  layer.add_services services_from(tds[-2], remarks)
                end
                layer.timetable = timetable_from! remarks
                layer.remarks = remarks_from remarks
                airspace.add_layer layer
              end
            rescue => error
              warn("error parsing #{airspace.type} `#{airspace.name}' at ##{index}: #{error.message}", pry: error)
            end
          end
          add airspace if airspace
        end
      end

      private

      def airspace_from(td)
        spans = td.children.split { |e| e.name == 'br' }.first.css(:span).drop_while { |e| e.text.match? '\s' }
        source_type = spans[0].text.blank_to_nil
        fail "unknown type `#{source_type}'" unless SOURCE_TYPES.has_key? source_type
        AIXM.airspace(
          name: anglicise(name: spans[1..-1].join(' ')),
          type: SOURCE_TYPES.dig(source_type, :type),
          local_type: SOURCE_TYPES.dig(source_type, :local_type)
        ).tap do |airspace|
          airspace.source = source(position: td.line)
        end
      end

      def class_from(text)
        text.strip
      end

      def services_from(td, remarks)
        text = td.text.cleanup
        text = SERVICE_FIXES.fetch(text, text)   # fix incomplete service columns
        text.gsub!(/(info|app)\s+([\d.]{3,})/i, "\\1\n\\2")   # put frequencies on separate line
        text.gsub!(/(\d)\s*\/\s*(\d)/, "\\1\n\\2")   # split frequencies onto separate lines
        units, services = [], []
        text.split("\n").each do |line|
          case line
          when /^(.+(?:info|app))$/i   # service
            callsign = $1
            service = AIXM.service(
# TODO: add source as soon as it is supported by components
#             source: source(position: td.line),
              type: :flight_information_service
            ).tap do |service|
              service.timetable = AIXM::H24 if remarks.match? /h\s?24/i
            end
            services << [service, callsign]
            units.shift.add_service service
          when /^(.*?)(\d{3}[.\d]*)(.*)$/   # frequency
            label, freq, footnote = $1, $2, $3
            service, callsign = services.last
            frequency = AIXM.frequency(
              transmission_f: AIXM.f(freq.to_f, :mhz),
              callsigns: { en: callsign, fr: callsign }
            ).tap do |frequency|
              frequency.type = :standard
              frequency.timetable = AIXM::H24 if remarks.match? /h\s?24/i
              frequency.remarks = [
                (remarks.extract(/#{Regexp.escape(footnote.strip)}\s*([^\n]+)/).join(' / ') unless footnote.empty?),
                label.strip
              ].map(&:blank_to_nil).compact.join(' / ').blank_to_nil
            end
            service.add_frequency frequency
          when /.*(?<!info|app|\d{3}|\))$/i   # unit
            unit = AIXM.unit(
              source: source(position: td.line),
              organisation: organisation_lf,   # TODO: not yet implemented
              name: line,
              type: :flight_information_centre,
              class: :icao
            )
            units << ((u = find(unit).first) ? (unit = u) : (add unit))
          else
            fail("cannot parse `#{text}'")
          end
        end
        services = services.map(&:first)
        fail("at least one service has no frequency") if services.any? { _1.frequencies.none? }
        services
      end

      def remarks_from(text)
        text.strip.gsub(/(\s)\s+/, '\1').blank_to_nil
      end
    end
  end
end
