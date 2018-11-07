module AIPP
  module LF
    class ENR21 < AIP
      using AIPP::Refinements
      using AIXM::Refinements

      # Map source types to type and local type
      SOURCE_TYPES = {
        'FIR' => { type: 'FIR', local_type: nil },
        'UIR' => { type: 'UIR', local_type: nil },
        'UTA' => { type: 'UTA', local_type: nil },
        'CTA' => { type: 'CTA', local_type: nil },
        'LTA' => { type: 'CTA', local_type: 'LTA' },
        'TMA' => { type: 'TMA', local_type: nil },
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
        html.css('tbody').each do |tbody|
          airspace = nil
          tbody.css('tr').to_enum.with_index(1).each do |tr, index|
            if tr.attr(:id).match?(/--TXT_NAME/)
              aixm.features << airspace if airspace
              airspace = airspace_from cleanup(node: tr).css(:td).first
              info "Parsing #{airspace.type} #{airspace.name}" unless airspace.type == :terminal_control_area
              next
            end
            begin
              tds = cleanup(node: tr).css('td')
              if airspace.type == :terminal_control_area && tds[0].text.blank_to_nil
                airspace = airspace_from tds[0]
                info "Parsing #{airspace.type} #{airspace.name}"
              end
              if airspace
                if tds[0].text.blank_to_nil
                  airspace.geometry = geometry_from tds[0]
                  fail("geometry is not closed") unless airspace.geometry.closed?
                end
                layer = layer_from(tds[-3])
                layer.class = class_from(tds[1]) if tds.count == 5
                layer.location_indicator = LOCATION_INDICATORS.fetch("#{airspace.type} #{airspace.name}", nil)
                # TODO: unit, call sign and frequency from tds[-2]
                layer.timetable = timetable_from(tds[-1])
                layer.remarks = remarks_from(tds[-1])
                airspace.layers << layer
              end
            rescue => error
              warn("error parsing #{airspace.type} `#{airspace.name}' at ##{index}: #{error.message}", context: error)
            end
          end
          aixm.features << airspace if airspace
        end
      end

      private

      def source_for(td)
        ['LF', 'ENR', 'ENR-2.1', options[:airac].date.xmlschema, td.line].join('|')
      end

      def airspace_from(td)
        spans = td.children.split { |e| e.name == 'br' }.first.css(:span).drop_while { |e| e.text.match? '\s' }
        source_type = spans[0].text.blank_to_nil
        fail "unknown type `#{source_type}'" unless SOURCE_TYPES.has_key? source_type
        AIXM.airspace(
          name: anglicise(name: spans[1..-1].join(' ')),
          type: SOURCE_TYPES.dig(source_type, :type),
          local_type: SOURCE_TYPES.dig(source_type, :local_type)
        ).tap do |airspace|
          airspace.source = source_for(td)
        end
      end

      def class_from(td)
        td.text.strip
      end

      def layer_from(td)
        above, below = td.text.gsub(/ /, '').split(/\n+/).select(&:blank_to_nil).split { |e| e.match? '---+' }
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

      def remarks_from(td)
        td.text.strip.gsub(/(\s)\s+/, '\1').blank_to_nil
      end
    end
  end
end
