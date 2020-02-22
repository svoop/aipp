module AIPP
  module LF
    module Helpers
      module Base

        using AIXM::Refinements

        # Map border names to OFMX
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

        # Intersection points between three countries
        INTERSECTIONS = {
          'FRANCE_SPAIN|ANDORRA_SPAIN' => AIXM.xy(lat: 42.502720, long: 1.725965),
          'ANDORRA_SPAIN|FRANCE_SPAIN' => AIXM.xy(lat: 42.603571, long: 1.442681),
          'FRANCE_SWITZERLAND|FRANCE_ITALY' => AIXM.xy(lat: 45.922701, long: 7.044125),
          'BELGIUM_FRANCE|FRANCE_LUXEMBOURG' => AIXM.xy(lat: 49.546428, long: 5.818415),
          'FRANCE_LUXEMBOURG|FRANCE_GERMANY' => AIXM.xy(lat: 49.469438, long: 6.367516),
          'FRANCE_GERMANY|FRANCE_SWITZERLAND' => AIXM.xy(lat: 47.589831, long: 7.589049),
          'GERMANY_SWITZERLAND|FRANCE_GERMANY' => AIXM.xy(lat: 47.589831, long: 7.589049)
        }.freeze

        # Map surface to OFMX composition, preparation and remarks
        SURFACES = {
          /^revêtue?$/ => { preparation: :paved },
          /^non revêtue?$/ => { preparation: :natural },
          'macadam' => { composition: :macadam },
          /^bitume ?(traité|psp)?$/ =>  { composition: :bitumen },
          'ciment' => { composition: :concrete, preparation: :paved },
          /^b[eéè]ton ?(armé|bitume|bitumineux)?$/ => { composition: :concrete, preparation: :paved },
          /^béton( de)? ciment$/ => { composition: :concrete, preparation: :paved },
          'béton herbe' => { composition: :concrete_and_grass },
          'béton avec résine' => { composition: :concrete, preparation: :paved, remarks: 'Avec résine / with resin' },
          "béton + asphalte d'étanchéité sablé" => { composition: :concrete_and_asphalt, preparation: :paved, remarks: 'Étanchéité sablé / sandblasted waterproofing' },
          'béton armé + support bitumastic' => { composition: :concrete, preparation: :paved, remarks: 'Support bitumastic / bitumen support' },
          /résine (époxy )?su[er] béton/ => { composition: :concrete, preparation: :paved, remarks: 'Avec couche résine / with resin seal coat' },
          /^(asphalte|tarmac)$/ => { composition: :asphalt, preparation: :paved },
          'enrobé' => { preparation: :other, remarks: 'Enrobé / coated' },
          'enrobé anti-kérozène' => { preparation: :other, remarks: 'Enrobé anti-kérozène / anti-kerosene coating' },
          /^enrobé bitum(e|iné|ineux)$/ => { composition: :bitumen, preparation: :paved, remarks: 'Enrobé / coated' },
          'enrobé béton' => { composition: :concrete, preparation: :paved, remarks: 'Enrobé / coated' },
          /^résine( époxy)?$/ => { composition: :other, remarks: 'Résine / resin' },
          'tole acier larmé' => { composition: :metal, preparation: :grooved },
          /^(structure métallique|aluminium)$/ => { composition: :metal },
          'matériaux composites ignifugés' => { composition: :other, remarks: 'Matériaux composites ignifugés / fire resistant mixed materials' },
          /^(gazon|herbe)$/ => { composition: :grass },
          'neige' => { composition: :snow },
          'neige damée' => { composition: :snow, preparation: :rolled }
        }.freeze

        # Transform French text fragments to English
        ANGLICISE_MAP = {
          /[^A-Z0-9 .\-]/ => '',
          /0(\d)/ => '\1',
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

        def prepare(html:)
          html.tap do |node|
            node.css('del, *[class*="AmdtDeletedAIRAC"]').each(&:remove)   # remove deleted entries
          end
        end

        def anglicise(name:)
          name&.uptrans&.tap do |string|
            ANGLICISE_MAP.each do |regexp, replacement|
              string.gsub!(regexp, replacement)
            end
          end
        end

        # Parsers

        def source(position:, aip_file: nil)
          aip_file ||= @aip
          [
            options[:region],
            aip_file.split('-').first,
            aip_file,
            options[:airac].date.xmlschema,
            position
          ].join('|')
        end

        def xy_from(text)
          parts = text.strip.split(/\s+/)
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

        def elevation_from(text)
          value, unit = text.strip.split
          AIXM.z(AIXM.d(value.to_i, unit).to_ft.dist, :qnh)
        end

        def layer_from(text_for_limit, text_for_class=nil)
          above, below = text_for_limit.gsub(/ /, '').split(/\n+/).select(&:blank_to_nil).split { |e| e.match? '---+' }
          AIXM.layer(
            class: text_for_class,
            vertical_limit: AIXM.vertical_limit(
              upper_z: z_from(above[0]),
              max_z: z_from(above[1]),
              lower_z: z_from(below[0]),
              min_z: z_from(below[1])
            )
          )
        end

        def geometry_from(text)
          AIXM.geometry.tap do |geometry|
            buffer = {}
            text.gsub(/\s+/, ' ').strip.split(/ - /).append('end').each do |element|
              case element
              when /arc (anti-)?horaire .+ sur (\S+) , (\S+)/i
                geometry.add_segment AIXM.arc(
                  xy: buffer.delete(:xy),
                  center_xy: AIXM.xy(lat: $2, long: $3),
                  clockwise: $1.nil?
                )
              when /cercle de ([\d\.]+) (NM|km|m) .+ sur (\S+) , (\S+)/i
                geometry.add_segment AIXM.circle(
                  center_xy: AIXM.xy(lat: $3, long: $4),
                  radius: AIXM.d($1.to_f, $2)
                )
              when /end|(\S+) , (\S+)/
                geometry.add_segment AIXM.point(xy: buffer[:xy]) if buffer.has_key?(:xy)
                buffer[:xy] = AIXM.xy(lat: $1, long: $2) if $1
                if border = buffer.delete(:border)
                  from = border.nearest(xy: geometry.segments.last.xy)
                  to = border.nearest(xy: buffer[:xy], geometry_index: from.geometry_index)
                  geometry.add_segments border.segment(from_position: from, to_position: to).map(&:to_point)
                end
              when /^frontière ([\w-]+)/i, /^(\D[^(]+)/i
                border_name = BORDERS.fetch($1.downcase.strip)
                if borders.has_key? border_name   # border from GeoJSON
                  buffer[:border] = borders[border_name]
                else   # named border
                  buffer[:xy] ||= INTERSECTIONS.fetch("#{buffer[:border_name]}|#{border_name}")
                  buffer[:border_name] = border_name
                  if border_name == 'FRANCE_SPAIN'   # specify which part of this split border
                    border_name += buffer[:xy].lat < 42.55 ? '_EAST' : '_WEST'
                  end
                  geometry.add_segment AIXM.border(
                    xy: buffer.delete(:xy),
                    name: border_name
                  )
                end
              else
                fail "geometry `#{element}' not recognized"
              end
            end
          end
        end

        def timetable_from!(text)
          if text.gsub!(/^\s*#{AIXM::H_RE}\s*$/, '')
            AIXM.timetable(code: Regexp.last_match&.to_s&.strip)
          end
        end

      end
    end
  end
end
