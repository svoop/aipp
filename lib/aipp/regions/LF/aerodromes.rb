module AIPP
  module LF

    class Aerodromes < AIP

      include AIPP::LF::Helpers::Base
      include AIPP::LF::Helpers::UsageLimitation
      include AIPP::LF::Helpers::Surface

      APPROACH_LIGHTING_TYPES = {
        'CAT I' => :cat_1,
        'CAT II' => :cat_2,
        'CAT III' => :cat_3,
        'CAT II-III' => :cat_2_and_3
      }.freeze

      LIGHTING_POSITIONS = {
        threshold: 'Thr',
        touch_down_zone: 'Tdz',
        center_line: 'Axe',
        edge: 'Bord',
        runway_end: 'Fin',
        stopway_center_line: 'Swy'
      }.freeze

      LIGHTING_COLORS = {
        'W' => :white,
        'R' => :red,
        'G' => :green,
        'B' => :blue,
        'Y' => :yellow
      }.freeze

      ICAO_LIGHTING_COLORS = {
        center_line: :white,
        edge: :white
      }.freeze

      def parse
        cache.ad.css(%Q(Ad[lk^="[LF]"])).each do |ad_node|
          # Build airport
          next unless limitation_type = LIMITATION_TYPES.fetch(ad_node.(:AdStatut))
          airport = AIXM.airport(
            source: source(section: 'AD', position: ad_node.line),
            organisation: organisation_lf,
            id: id_from(ad_node.(:AdCode)),
            name: ad_node.(:AdNomComplet),
            xy: xy_from(ad_node.(:Geometrie))
          ).tap do |airport|
            airport.meta = ad_node.attr('pk')
            airport.z = given(ad_node.(:AdRefAltFt)) { AIXM.z(_1.to_i, :qnh) }
            airport.declination = ad_node.(:AdMagVar)&.to_f
            airport.add_usage_limitation(type: limitation_type.fetch(:limitation)) do |limitation|
              limitation.remarks = limitation_type[:remarks]
              [
                (:scheduled if ad_node.(:TfcRegulier?)),
                (:not_scheduled if ad_node.(:TfcNonRegulier?)),
                (:private if ad_node.(:TfcPrive?)),
                (:other unless ad_node.(:TfcRegulier?) || ad_node.(:TfcNonRegulier?) || ad_node.(:TfcPrive?))
              ].compact.each do |purpose|
                limitation.add_condition do |condition|
                  condition.realm = limitation_type.fetch(:realm)
                  condition.origin = case
                    when ad_node.(:TfcIntl?) && ad_node.(:TfcNtl?) then :any
                    when ad_node.(:TfcIntl?) then :international
                    when ad_node.(:TfcNtl?) then :national
                    else :other
                  end
                  condition.rule = case
                    when ad_node.(:TfcIfr?) && ad_node.(:TfcVfr?) then :ifr_and_vfr
                    when ad_node.(:TfcIfr?) then :ifr
                    when ad_node.(:TfcVfr?) then :vfr
                    else
                      warn("falling back to VFR rule for `#{airport.id}'", severe: false)
                      :vfr
                  end
                  condition.purpose = purpose
                end
              end
            end
# TODO: link to VAC once supported downstream
#           # Link to VAC
#           airport.remarks = [
#             airport.remarks.to_s,
#             link_to('VAC-AD', url_for("VAC-#{airport.id}"))
#           ].join("\n")
            cache.rwy.css(%Q(Rwy:has(Ad[pk="#{ad_node.attr(:pk)}"]))).each do |rwy_node|
              add_runway_to(airport, rwy_node)
            end
          end
          add airport
        end
      end

      private

      def id_from(content)
        case content
          when /^\d{2}$/ then 'LF00' + content   # private aerodromes without official ID
          else 'LF' + content
        end
      end

      def add_runway_to(airport, rwy_node)
        AIXM.runway(
          name: rwy_node.(:Rwy)
        ).tap do |runway|
          rwylgt_nodes = cache.rwylgt.css(%Q(RwyLgt:has(Rwy[pk="#{rwy_node.attr(:pk)}"])))
          airport.add_runway(runway)
          runway.dimensions = AIXM.r(AIXM.d(rwy_node.(:Longueur)&.to_i, :m), AIXM.d(rwy_node.(:Largeur)&.to_i, :m))
          runway.surface = surface_from(rwy_node)
          runway.forth.geographic_bearing = given(rwy_node.(:OrientationGeo)) { AIXM.a(_1.to_f) }
          runway.forth.xy = given(rwy_node.(:LatThr1), rwy_node.(:LongThr1)) { AIXM.xy(lat: _1.to_f, long: _2.to_f) }
          runway.forth.displaced_threshold = given(rwy_node.(:LatDThr1), rwy_node.(:LongDThr1)) { AIXM.xy(lat: _1.to_f, long: _2.to_f) }
          runway.forth.z = given(rwy_node.(:AltFtDThr1)) { AIXM.z(_1.to_i, :qnh) }
          runway.forth.z ||= given(rwy_node.(:AltFtThr1)) { AIXM.z(_1.to_i, :qnh) }
          if rwylgt_node = rwylgt_nodes[0]
            runway.forth.vasis = vasis_from(rwylgt_node)
            given(approach_lighting_from(rwylgt_node)) { runway.forth.add_approach_lighting(_1) }
            LIGHTING_POSITIONS.each_key do |position|
              given(lighting_from(rwylgt_node, position)) { runway.forth.add_lighting(_1) }
            end
          end
          if rwy_node.(:Rwy).match? '/'
            runway.back.xy = given(rwy_node.(:LatThr2), rwy_node.(:LongThr2)) { AIXM.xy(lat: _1.to_f, long: _2.to_f) }
            runway.back.displaced_threshold = given(rwy_node.(:LatDThr2), rwy_node.(:LongDThr2)) { AIXM.xy(lat: _1.to_f, long: _2.to_f) }
            runway.back.z = given(rwy_node.(:AltFtDThr2)) { AIXM.z(_1.to_i, :qnh) }
            runway.back.z ||= given(rwy_node.(:AltFtThr2)) { AIXM.z(_1.to_i, :qnh) }
            if rwylgt_node = rwylgt_nodes[1]
              runway.back.vasis = vasis_from(rwylgt_node)
              given(approach_lighting_from(rwylgt_node)) { runway.back.add_approach_lighting(_1) }
              LIGHTING_POSITIONS.each_key do |position|
                given(lighting_from(rwylgt_node, position)) { runway.back.add_lighting(_1) }
              end
            end
          end
        end
      end

      def vasis_from(rwylgt_node)
        if rwylgt_node.(:PapiVasis)
          AIXM.vasis.tap do |vasis|
            vasis.type = rwylgt_node.(:PapiVasis)
            vasis.slope_angle = AIXM.a(rwylgt_node.(:PapiVasisPente).to_f)
            vasis.meht = AIXM.z(rwylgt_node.(:MehtFt).to_i, :qfe)
          end
        end
      end

      def approach_lighting_from(rwylgt_node)
        if rwylgt_node.(:LgtApchCat)
          AIXM.approach_lighting(
            type: APPROACH_LIGHTING_TYPES.fetch(rwylgt_node.(:LgtApchCat) , :other)
          ).tap do |approach_lighting|
            approach_lighting.length = AIXM.d(rwylgt_node.(:LgtApchLongueur).to_i, :m) if rwylgt_node.(:LgtApchLongueur)
            approach_lighting.intensity = rwylgt_node.(:LgtApchIntensite)&.first_match(/LIH/, /LIM/, /LIL/, default: :other)
            approach_lighting.remarks = {
              'type' => (rwylgt_node.(:LgtApchCat) if approach_lighting.type == :other),
              'intensité/intensity' => (rwylgt_node.(:LgtApchIntensite) if approach_lighting.intensity == :other)
            }.to_remarks
          end
        end
      end

      def lighting_from(rwylgt_node, position)
        prefix = "Lgt" + LIGHTING_POSITIONS.fetch(position)
        if rwylgt_node.(:"#{prefix}Couleur") || rwylgt_node.(:"#{prefix}Longueur")
          AIXM.lighting(position: position).tap do |lighting|
            couleur, intensite = rwylgt_node.(:"#{prefix}Couleur"), rwylgt_node.(:"#{prefix}Intensite")
            lighting.intensity = if intensite
              intensite.first_match(/LIH/, /LIM/, /LIL/, default: :other)
            elsif couleur
              couleur.first_match(/LIH/, /LIM/, /LIL/).tap { couleur.remove!(/LIH|LIM|LIL/) }
            end
            lighting.color = if couleur
              if couleur.match? /ICAO|EASA|OACI|AESA/
                ICAO_LIGHTING_COLORS[position]
              else
                couleur.remove(/[^#{LIGHTING_COLORS.keys.join}]/).compact
                LIGHTING_COLORS.fetch(couleur, :other)
              end
            end
            lighting.description = {
              'couleur/color' => (rwylgt_node.(:"#{prefix}Couleur") if [nil, :other].include?(lighting.color)),
              'longueur/length' =>  rwylgt_node.(:"#{prefix}Longueur"),
              'espace/spacing' => rwylgt_node.(:"#{prefix}Espace")
            }.to_remarks
            lighting.remarks = rwylgt_node.(:LgtRem)
          end
        end
      end

      patch AIXM::Feature::Airport, :xy do |parser, object, value|
        throw(:abort) unless coordinate = parser.fixture.dig(object.id, 'xy')
        lat, long = coordinate.split(/\s+/)
        AIXM.xy(lat: lat, long: long)
      end

      patch AIXM::Feature::Airport, :z do |parser, object, value|
        throw(:abort) unless value.nil?
        throw(:abort, 'fixture missing') unless elevation = parser.fixture.dig(object.id, 'z')
        AIXM.z(elevation, :qnh)
      end

      patch AIXM::Component::Runway, :dimensions do |parser, object, value|
        throw(:abort) unless value.surface.zero?
        throw(:abort, 'fixture missing') unless dimensions = parser.fixture.dig(object.airport.id, object.name, 'dimensions')
        length, width = dimensions.split(/\D+/)
        length = length&.match?(/^\d+$/) ? AIXM.d(length.to_i, :m) : value.length
        width = width&.match?(/^\d+$/) ? AIXM.d(width.to_i, :m) : value.width
        AIXM.r(length, width).tap { |r| throw(:abort, 'fixture incomplete') if r.surface.zero? }
      end

      patch AIXM::Component::Runway::Direction, :xy do |parser, object, value|
        throw(:abort) unless value.nil?
        throw(:abort, 'fixture missing') unless coordinate = parser.fixture.dig(object.runway.airport.id, object.name.to_s(:runway), 'xy')
        lat, long = coordinate.split(/\s+/)
        AIXM.xy(lat: lat, long: long)
      end

    end
  end
end
