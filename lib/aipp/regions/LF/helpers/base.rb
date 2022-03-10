module AIPP
  module LF
    module Helpers
      module Base

        using AIXM::Refinements

        # Supported version of the XML_SIA database dump
        VERSION = '5'.freeze

        # Mandatory Interface

        def setup
          AIXM.config.voice_channel_separation = :any
          unless AIPP.cache.espace
            xml = read('XML_SIA')
            %i(Ad Bordure Espace Frequence Helistation NavFix Obstacle Partie RadioNav Rwy RwyLgt Service Volume).each do |table|
              AIPP.cache[table.downcase] = xml.css("#{table}S")
            end
            warn("XML_SIA database dump version mismatch") unless xml.at_css('SiaExport').attr(:Version) == VERSION
          end
        end

        def url_for(document)
          sia_date = AIPP.options.airac.date.strftime('%d_%^b_%Y')   # 04_JAN_2018
          xml_date = AIPP.options.airac.date.xmlschema               # 2018-01-04
          sia_url = "https://www.sia.aviation-civile.gouv.fr/dvd/eAIP_#{sia_date}"
          case document
          when /^Obstacles$/   # obstacles spreadsheet
            "#{sia_url}/FRANCE/ObstaclesDataZone1MFRANCE_#{xml_date.remove('-')}.xlsx"
#         when /^VAC\-(\w+)/   # aerodrome VAC PDF
#           "#{sia_url}/Atlas-VAC/PDF_AIPparSSection/VAC/AD/AD-2.#{$1}.pdf"
#         when /^VACH\-(\w+)/   # helipad VAC PDF
#           "#{sia_url}/Atlas-VAC/PDF_AIPparSSection/VACH/AD/AD-3.#{$1}.pdf"
#         when /^[A-Z]+-/   # eAIP HTML page (e.g. ENR-5.5)
#           "#{sia_url}/FRANCE/AIRAC-#{xml_date}/html/eAIP/FR-#{document}-fr-FR.html"
          else   # SIA XML database dump
            "XML_SIA_#{xml_date}.xml"
          end
        end

        # Templates

        def organisation_lf
          unless AIPP.cache.organisation_lf
            AIPP.cache.organisation_lf = AIXM.organisation(
              source: source(position: 1, document: "GEN-3.1"),
              name: 'FRANCE',
              type: 'S'
            ).tap do |organisation|
              organisation.id = 'LF'
            end
            add AIPP.cache.organisation_lf
          end
          AIPP.cache.organisation_lf
        end

        # Parsersettes

        # Build a source string
        #
        # @param position [Integer] line on which to find the information
        # @param part [String] override autodetected part (e.g. "ENR")
        # @param document [String] override autodetected document (e.g. "ENR-2.1")
        # @return [String] source string
        def source(position:, part: nil, document: nil)
          document ||= 'XML_SIA'
          part ||= document.split(/-(?=\d)/).first
          [
            AIPP.options.region,
            part,
            document,
            AIPP.options.airac.date.xmlschema,
            position
          ].join('|')
        end

        # Convert content to boolean
        #
        # @param content [String] either "oui" or "non"
        # @return [Boolean]
        def b_from(content)
          case content
            when 'oui' then true
            when 'non' then false
            else fail "`#{content}' is not boolean content"
          end
        end

        # Build coordinates from content
        #
        # @param content [String] source content
        # @return [AIXM::XY]
        def xy_from(content)
          parts = content.split(/[\s,]+/)
          AIXM.xy(lat: parts[0].to_f, long: parts[1].to_f)
        end

        # Build altitude/elevation from value and unit
        #
        # @param value [String, Numeric, nil] numeric value
        # @param unit [String] unit like "ft ASFC" or absolute like "SFC"
        # @return [AIXM::Z]
        def z_from(value: nil, unit: 'ft ASFC')
          if value
            case unit
              when 'SFC' then AIXM::GROUND
              when 'UNL' then AIXM::UNLIMITED
              when 'ft ASFC' then AIXM.z(value.to_i, :qfe)
              when 'ft AMSL' then AIXM.z(value.to_i, :qnh)
              when 'FL' then AIXM.z(value.to_i, :qne)
              else fail "z `#{[value, unit].join(' ')}' not recognized"
            end
          end
        end

        # Build distance from content
        #
        # @param content [String] source content
        # @return [AIXM::D]
        def d_from(content)
          parts = content.split(/\s/)
          AIXM.d(parts[0].to_f, parts[1])
        end

        # Build geometry from content
        #
        # @param content [String] source content
        # @return [AIXM::Component::Geometry]
        def geometry_from(content)
          AIXM.geometry.tap do |geometry|
            buffer = {}
            content.split("\n").each do |element|
              parts = element.split(',', 3).last.split(/[():,]/)
              # Write explicit geometry from previous iteration
              if (bordure_name, xy = buffer.delete(:fnt))
                border = AIPP.borders.send(bordure_name)
                geometry.add_segments border.segment(
                  from_position: border.nearest(xy: xy),
                  to_position: border.nearest(xy: xy_from(parts[0]))
                ).map(&:to_point)
              end
              # Write current iteration
              geometry.add_segment(
                case parts[1]
                when 'grc'
                  AIXM.point(
                    xy: xy_from(parts[0])
                  )
                when 'rhl'
                  AIXM.rhumb_line(
                    xy: xy_from(parts[0])
                  )
                when 'cwa', 'cca'
                  AIXM.arc(
                    xy: xy_from(parts[0]),
                    center_xy: xy_from(parts[5]),
                    clockwise: (parts[1] == 'cwa')
                  )
                when 'cir'
                  AIXM.circle(
                    center_xy: xy_from(parts[0]),
                    radius: d_from(parts[3..4].join(' '))
                  )
                when 'fnt'
                  bordure = AIPP.cache.bordure.at_css(%Q(Bordure[pk="#{parts[3]}"]))
                  bordure_name = bordure.(:Code)
                  if bordure_name.match? /:/   # explicit geometry
                    AIPP.borders[bordure_name] ||= AIPP::Border.from_array([bordure.(:Geometrie).split])
                    buffer[:fnt] = [bordure_name, xy_from(parts[2])]
                    AIXM.point(
                      xy: xy_from(parts[0])
                    )
                  else
                    AIXM.border(   # named border
                      xy: xy_from(parts[0]),
                      name: bordure_name
                    )
                  end
                else
                  fail "geometry `#{parts[1]}' not recognized"
                end
              )
            end
          end
        end

        # Build timetable from content
        #
        # @param content [String] source content
        # @return [AIXM::Component::Timetable]
        def timetable_from(content)
          AIXM.timetable(code: content) if AIXM::H_RE.match? content
        end

        # Build layer from "volume" node
        #
        # @param volume_node [Nokogiri::XML::Element] source node
        # @return [AIXM::Component::Layer]
        def layer_from(volume_node)
          AIXM.layer(
            class: volume_node.(:Classe),
            vertical_limit: AIXM.vertical_limit(
              upper_z: z_from(value: volume_node.(:Plafond), unit: volume_node.(:PlafondRefUnite)),
              max_z: z_from(value: volume_node.(:Plafond2)),
              lower_z: z_from(value: volume_node.(:Plancher), unit: volume_node.(:PlancherRefUnite)),
              min_z: z_from(value: volume_node.(:Plancher2))
            )
          ).tap do |layer|
            layer.timetable = timetable_from(volume_node.(:HorCode))
            layer.remarks = volume_node.(:Remarque)
          end
        end

      end
    end
  end
end
