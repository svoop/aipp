module AIPP
  module LF
    module Helpers
      module Common

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
          'la côte atlantique française' => 'FRANCE_ATLANTIC_COAST',   # TODO: handle internally
          'côte méditérrannéenne' => 'FRANCE_MEDITERRANEAN_COAST',   # TODO: handle internally
          'limite des eaux territoriales atlantique françaises' => 'FRANCE_ATLANTIC_TERRITORIAL_SEA',   # TODO: handle internally
          'parc national des écrins' => 'FRANCE_ECRINS_NATIONAL_PARK'   # TODO: handle internally
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
        }

        # Map surface compositions to OFMX composition and preparation
        COMPOSITIONS = {
          'revêtue' => { preparation: :paved },
          'non revêtue' => { preparation: :natural },
          'macadam' => { composition: :macadam },
          'béton' => { composition: :concrete, preparation: :paved },
          'béton bitumineux' => { composition: :bitumen, preparation: :paved },
          'enrobé bitumineux' => { composition: :bitumen },
          'asphalte' => { composition: :asphalt, preparation: :paved },
          'gazon' => { composition: :grass }
        }

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
            node.css('del, tr[class*="AmdtDeletedAIRAC"]').each(&:remove)   # remove deleted entries
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

        def layer_from(text_for_limits, text_for_class=nil)
          above, below = text_for_limits.gsub(/ /, '').split(/\n+/).select(&:blank_to_nil).split { |e| e.match? '---+' }
          above.reverse!
          AIXM.layer(
            class: text_for_class,
            vertical_limits: AIXM.vertical_limits(
              max_z: z_from(above[1]),
              upper_z: z_from(above[0]),
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

        def timetable_from(text)
          AIXM::H24 if text.gsub(/\W/, '') == 'H24'
        end

      end
    end
  end
end
