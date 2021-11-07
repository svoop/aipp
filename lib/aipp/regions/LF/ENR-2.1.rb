module AIPP
  module LF

    # FIR, TMA etc
    class ENR21 < AIP

      include AIPP::LF::Helpers::Base

      # Airspaces by type to be ignored
      NAME_DENYLIST_RE = {
        all: /deleg/i,                     # delegated zones
        terminal_control_area: /geneve/i   # TMA GENEVA is included FYI only
      }.freeze

      # Map source types to type and optional local type
      SOURCE_TYPES = {
        'FIR' => { type: 'FIR' },
        'UIR' => { type: 'UIR' },
        'UTA' => { type: 'UTA' },
        'CTA' => { type: 'CTA' },
        'LTA' => { type: 'CTA', local_type: 'LTA' },
        'TMA' => { type: 'TMA' },
        'SIV' => { type: 'SECTOR', local_type: 'FIZ/SIV' }   # providing FIS
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
        "APP IROISE 119.575 (1)\nIROISE INFO 135.825" => "APP IROISE\nIROISE INFO\n119.575 (1)\n135.825",
        "APP IROISE 119.575 (1)\nIROISE INFO 119.575" => "APP IROISE\nIROISE INFO\n119.575 (1)\n119.575",
        "APP LANDIVISIAU 122.400\nAPP IROISE 119.575 (1)\nLANDIVISIAU INFO 122.400\nIROISE INFO 119.575" => "APP LANDIVISIAU\nLANDIVISIAU INFO \n119.575 (1)\n122.400\nAPP IROISE\nIROISE INFO\n119.575 (1)\n122.400",
        "NANTES INFO 122.800 - 119.400(s)" => "APP NANTES\nNANTES INFO\n122.800\n119.400",
        "NANTES INFO 130.275 - 119.400(s)" => "APP NANTES\nNANTES INFO\n130.275\n119.400",
        "119.535 - 121.215(s)" => "APP NANTES\nNANTES INFO\n119.535\n121.215"
      }.freeze

      def parse
        prepare(html: read).css('tbody').each do |tbody|
          airspace = nil
          tbody.css('tr').to_enum.with_index(1).each do |tr, index|
            if tr.attr(:id).match?(/--TXT_NAME/)
              if airspace
                if NAME_DENYLIST_RE[:all]&.match?(airspace.name) || NAME_DENYLIST_RE[airspace.type]&.match?(airspace.name)
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
                  if NAME_DENYLIST_RE[:all]&.match?(airspace.name) || NAME_DENYLIST_RE[airspace.type]&.match?(airspace.name)
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
                if airspace.local_type == 'FIZ/SIV'   # services parsed for FIZ/SIV only
                  layer.add_services services_from(tds[-2], remarks, airspace)
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
        spans = td.children.split { _1.name == 'br' }.first.css(:span).drop_while { _1.text.match? '\s' }
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

      def services_from(td, remarks, airspace)
        raw_text = td.text.cleanup
        text = SERVICE_FIXES.fetch(raw_text, raw_text.dup)   # fix incomplete service columns
        text.remove! /\(s\)/i   # remove noise
        text.gsub!(/approche/i, 'app')   # force abbreviation
        text.gsub!(/[\/-]/, "\n")   # separate multiple frequencies
        text = text.gsub(/((?:[A-Z][a-z]\D+)?\d{3}\.\d+)/, "\n\\1").compact   # put frequencies on separate line
        fail "no unit found in #{raw_text.inspect}" unless text&.match? /^(fic|app|twr)/i
        units = []
        text.split(/[\a\n](?=(?:fic|app|twr))/i).map do |group|
          unit_name, service_name, comms = group.split(/\n/, 3)
          unit = AIXM.unit(
            source: source(position: td.line),
            organisation: organisation_lf,   # TODO: not yet implemented
            name: unit_name,
            type: :flight_information_centre,
            class: :icao
          )
          fail "invalid service in #{raw_text.inspect}" unless service_name&.match? /(info|app)$/i
          service = AIXM.service(
            # TODO: add source as soon as it is supported by components
            # source: source(position: td.line),
            type: :flight_information_service
          ).tap do |service|
            service.timetable = AIXM::H24 if remarks.match? /h\s?24/i
          end
          comms.split("\n").each do |comm|
            label, frequency, footnote = comm.partition /\d{3}\.\d+/
            fail "invalid frequency in #{raw_text.inspect}" unless frequency
            service.add_frequency(
              AIXM.frequency(
                transmission_f: AIXM.f(frequency.to_f, :mhz),
                callsigns: { en: service_name, fr: service_name }
              ).tap do |frequency|
                frequency.type = :standard
                frequency.timetable = AIXM::H24 if remarks.match? /h\s?24/i
                frequency.remarks = [
                  (remarks.extract(/#{Regexp.escape(footnote.strip)}\s*([^\n]+)/).join(' / ') unless footnote.empty?),
                  label.strip
                ].map(&:blank_to_nil).compact.join(' / ').blank_to_nil
              end
            )
          end
          units << ((u = find(unit).first) ? (unit = u) : (add unit))
          unit.add_service service
          service
        end
      end

      def remarks_from(text)
        text.strip.gsub(/(\s)\s+/, '\1').blank_to_nil
      end
    end
  end
end
