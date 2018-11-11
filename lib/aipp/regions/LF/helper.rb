module AIPP
  module LF
    module Helper
      using AIPP::Refinements
      using AIXM::Refinements

      BORDERS = {
        'franco-allemande' => 'FRANCE_GERMANY',
        'franco-espagnole' =>  'FRANCE_SPAIN',
        'franco-italienne' => 'FRANCE_ITALY',
        'franco-suisse' => 'FRANCE_SWITZERLAND',
        'franco-luxembourgeoise' => 'FRANCE_LUXEMBOURG',
        'franco-belge' => 'BELGIUM_FRANCE',
        'germano-suisse' => 'GERMANY_SWITZERLAND',
        'hispano-andorrane' => 'ANDORRA_SPAIN',
        'la côte atlantique française' => 'FRANCE_ATLANTIC_COAST',
        'côte méditérrannéenne' => 'FRANCE_MEDITERRANEAN_COAST',
        'limite des eaux territoriales atlantique françaises' => 'FRANCE_ATLANTIC_TERRITORIAL_SEA',
        'parc national des écrins' => 'FRANCE_ECRINS_NATIONAL_PARK'
      }.freeze

      INTERSECTIONS = {
        'FRANCE_SPAIN|ANDORRA_SPAIN' => AIXM.xy(lat: 42.502720, long: 1.725965),
        'ANDORRA_SPAIN|FRANCE_SPAIN' => AIXM.xy(lat: 42.603571, long: 1.442681),
        'FRANCE_SWITZERLAND|FRANCE_ITALY' => AIXM.xy(lat: 45.922701, long: 7.044125),
        'BELGIUM_FRANCE|FRANCE_LUXEMBOURG' => AIXM.xy(lat: 49.546428, long: 5.818415),
        'FRANCE_LUXEMBOURG|FRANCE_GERMANY' => AIXM.xy(lat: 49.469438, long: 6.367516),
        'FRANCE_GERMANY|FRANCE_SWITZERLAND' => AIXM.xy(lat: 47.589831, long: 7.589049),
        'GERMANY_SWITZERLAND|FRANCE_GERMANY' => AIXM.xy(lat: 47.589831, long: 7.589049)
      }

      ANGLICISE_MAP = {
        /[^A-Z0-9 .\-]/ => '',
        / 0(\d)/ => ' \1',
        /(\d)-(\d)/ => '\1.\2',
        /PARTIE/ => '',
        /DELEG\./ => 'DELEG ',
        /FRANCAISE?/ => 'FR',
        /ANGLAISE?/ => 'UK',
        /BELGE/ => 'BE',
        /LUXEMBOURGEOISE?/ => 'LU',
        /ALLEMANDE?/ => 'DE',
        /SUISSE/ => 'CH',
        /ITALIEN(?:NE)?/ => 'IT',
        /ESPAGNOLE?/ => 'ES',
        /ANDORRANE?/ => 'AD',
        /NORD/ => 'N',
        /EST/ => 'E',
        /SUD/ => 'S',
        /OEST/ => 'W',
        /ANGLO NORMANDES/ => 'ANGLO-NORMANDES',
        / +/ => ' '
      }.freeze

      def url(aip:)
        "https://www.sia.aviation-civile.gouv.fr/dvd/eAIP_%s/FRANCE/AIRAC-%s/html/eAIP/FR-%s-fr-FR.html" % [
          options[:airac].date.strftime('%d_%^b_%Y'),   # 04_JAN_2018
          options[:airac].date.xmlschema,               # 2018-01-04
          aip                                           # ENR-5.1
        ]
      end

      # Templates

      def organisation_lf
        @organisation_lf ||= AIXM.organisation(
          name: 'FRANCE',
          type: 'S'
        ).tap do |organisation|
          organisation.id = 'LF'
        end
      end

      # Transformations

      def cleanup(node:)
        node.tap do |root|
          root.css('del').each { |n| n.remove }   # remove deleted entries
        end
      end

      def anglicise(name:)
        name.uptrans.tap do |string|
          ANGLICISE_MAP.each do |regexp, replacement|
            string.gsub!(regexp, replacement)
          end
        end
      end

      # Parsers

      def source_for(element)
        [
          options[:region],
          @aip.split('-').first,
          @aip,
          options[:airac].date.xmlschema,
          element.line
        ].join('|')
      end

      def xy_from(td)
        parts = td.text.strip.split(/\s+/)
        AIXM.xy(lat: parts[0], long: parts[1])
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

      def geometry_from(td)
        AIXM.geometry.tap do |geometry|
          buffer = {}
          td.text.gsub(/\s+/, ' ').strip.split(/ - /).append('end').each do |element|
            case element
            when /arc (anti-)?horaire .+ sur (\S+) , (\S+)/i
              geometry << AIXM.arc(
                xy: buffer.delete(:xy),
                center_xy: AIXM.xy(lat: $2, long: $3),
                clockwise: $1.nil?
              )
            when /cercle de ([\d\.]+) (NM|km|m) .+ sur (\S+) , (\S+)/i
              geometry << AIXM.circle(
                center_xy: AIXM.xy(lat: $3, long: $4),
                radius: AIXM.d($1.to_f, $2)
              )
            when /end|(\S+) , (\S+)/
              geometry << AIXM.point(xy: buffer[:xy]) if buffer.has_key?(:xy)
              buffer[:xy] = AIXM.xy(lat: $1, long: $2) if $1
            when /^frontière ([\w-]+)/i, /^(\D[^(]+)/i
              border_name = BORDERS.fetch($1.downcase.strip)
              buffer[:xy] ||= INTERSECTIONS.fetch("#{buffer[:border_name]}|#{border_name}")
              buffer[:border_name] = border_name
              if border_name == 'FRANCE_SPAIN'   # specify which part of this split border
                border_name += buffer[:xy].lat < 42.55 ? '_EAST' : '_WEST'
              end
              geometry << AIXM.border(
                xy: buffer.delete(:xy),
                name: border_name
              )
            else
              fail "geometry `#{element}' not recognized"
            end
          end
        end
      end

      def timetable_from(td)
        AIXM::H24 if td.text.gsub(/\W/, '') == 'H24'
      end

    end
  end
end
