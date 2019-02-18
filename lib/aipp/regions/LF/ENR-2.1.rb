module AIPP
  module LF

    # FIR, TMA etc
    class ENR21 < AIP

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

      def parse
        prepare(html: read).css('tbody').each do |tbody|
          airspace = nil
          tbody.css('tr').to_enum.with_index(1).each do |tr, index|
            if tr.attr(:id).match?(/--TXT_NAME/)
              aixm.features << airspace if airspace
              airspace = airspace_from tr.css(:td).first
              debug "Parsing #{airspace.type} #{airspace.name}" unless airspace.type == :terminal_control_area
              next
            end
            begin
              tds = tr.css('td')
              if airspace.type == :terminal_control_area && tds[0].text.blank_to_nil
                airspace = airspace_from tds[0]
                debug "Parsing #{airspace.type} #{airspace.name}"
              end
              if airspace
                if tds[0].text.blank_to_nil
                  airspace.geometry = geometry_from tds[0].text
                  fail("geometry is not closed") unless airspace.geometry.closed?
                end
                layer = layer_from(tds[-3].text)
                layer.class = class_from(tds[1].text) if tds.count == 5
                layer.location_indicator = LOCATION_INDICATORS.fetch("#{airspace.type} #{airspace.name}", nil)
                # TODO: unit, call sign and frequency from tds[-2]
                layer.timetable = timetable_from(tds[-1].text)
                layer.remarks = remarks_from(tds[-1].text)
                airspace.layers << layer
              end
            rescue => error
              warn("error parsing #{airspace.type} `#{airspace.name}' at ##{index}: #{error.message}", pry: error)
            end
          end
          write airspace if airspace
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

      def remarks_from(text)
        text.strip.gsub(/(\s)\s+/, '\1').blank_to_nil
      end
    end
  end
end
