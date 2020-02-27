module AIPP
  module LF

    # Helipads
    class AD31 < AIP

      include AIPP::LF::Helpers::Base
      using AIXM::Refinements

      DEPENDS = %w(AD-2)

      HOSTILITIES = {
        'zone hostile habitée' => 'Zone hostile habitée / hostile populated area',
        'zone hostile non habitée' => 'Zone hostile non habitée / hostile unpopulated area',
        'zone non hostile' => 'Zone non hostile / non-hostile area'
      }.freeze

      POSITIONINGS = {
        'en terrasse' => 'En terrasse / on deck',
        'en surface' => 'En surface / on ground'
      }.freeze

      DIMENSIONS_RE = /( diam.tre\s+\d+ | (?:\d[\s\d,.m]*x\s*){1,}[\s\d,.m]+ )/ix.freeze

      def parse
        prepare(html: read).css('tbody').each do |tbody|
          tbody.css('tr').to_enum.each_slice(3).with_index(1) do |trs, index|
            name = trs[0].css('span[id*="ADHP.TXT_NAME"]').text.cleanup.remove(/[^\w' ]/)
            if find_by(:airport, name: name).any?
              verbose_info "Skipping #{name} in favor of AD-2"
              next
            end
            # Airport
            @airport = AIXM.airport(
              source: source(position: trs[0].line),
              organisation: organisation_lf,   # TODO: not yet implemented
              id: options[:region],
              name: name,
              xy: xy_from(trs[1].css('td:nth-of-type(1)').text.cleanup)
            ).tap do |airport|
              airport.z = elevation_from(trs[1].css('td:nth-of-type(2)').text)
            end
            # Usage restrictions
            if trs[0].css('span[id*="ADHP.STATUT"]').text.match?(/usage\s+restreint/i)
              @airport.add_usage_limitation(type: :reservation_required) do |reservation_required|
                reservation_required.remarks = "Usage restreint / restricted use"
              end
            end
            if trs[0].css('span[id*="ADHP.STATUT"]').text.match?(/r.serv.\s+aux\s+administrations/i)
              @airport.add_usage_limitation(type: :other) do |other|
                other.remarks = "Réservé aux administrations de l'État / reserved for State administrations"
              end
            end
            # FATOs and helipads
            text = trs[2].css('span[id*="ADHP.REVETEMENT"]').text.remove(/tlof\s*|\s*\(.*?\)/i).downcase.compact
            surface = text.blank? ? {} : SURFACES.metch(text)
            lighting = lighting_from(trs[1].css('span[id*="ADHP.BALISAGE"]').text.cleanup)
            fatos_from(trs[1].css('span[id*="ADHP.DIM_FATO"]').text).each { |f| @airport.add_fato f }
            helipads_from(trs[1].css('span[id*="ADHP.DIM_TLOF"]').text).each do |helipad|
              helipad.surface.composition = surface[:composition]
              helipad.surface.preparation = surface[:preparation]
              helipad.surface.remarks = surface[:remarks]
              helipad.surface.auw_weight = auw_weight_from(trs[2].css('span[id*="ADHP.RESISTANCE"]').text)
              helipad.add_lighting(lighting) if lighting
              @airport.add_helipad helipad
            end
            # Operator and addresses
            operator = trs[0].css('span[id*="ADHP.EXPLOITANT"]')
            splitted = operator.text.split(/( (?<!\p{L})t[ée]l | fax | standard | [\d\s]{10,} | \.\s | \( )/ix, 2)
            @airport.operator = splitted[0].full_strip.truncate(60, omission: '…').blank_to_nil
            raw_addresses = splitted[1..].join.cleanup.full_strip
            addresses_from(splitted[1..].join, source(position: operator.first.line)).each { |a| @airport.add_address(a) }
            # Remarks
            @airport.remarks = [].tap do |remarks|
              hostility = trs[2].css('span[id*="ADHP.ZONE_HABITEE"]').text.cleanup.downcase.blank_to_nil
              hostility = HOSTILITIES.fetch(hostility) if hostility
              positioning = trs[2].css('span[id*="ADHP.EN_TERRASSE"]').text.cleanup.downcase.blank_to_nil
              positioning = POSITIONINGS.fetch(positioning) if positioning
              remarks << ('**SITUATION**' if hostility || positioning) << hostility << positioning << ''
              remarks << trs[2].css('td:nth-of-type(5)').text.cleanup
              remarks << raw_addresses unless raw_addresses.blank?
            end.compact.join("\n").strip
            add(@airport) if @airport.fatos.any? || @airport.helipads.any?
          end
        end
      end

      private

      def fatos_from(text)
        [
          if text.cleanup.match DIMENSIONS_RE
            AIXM.fato(name: 'FATO').tap do |fato|
              fato.length, fato.width = dimensions_from($1)
            end
          end
        ].compact
      end

      def helipads_from(text)
        [
          if text.cleanup.match DIMENSIONS_RE
            AIXM.helipad(name: 'TLOF', xy: @airport.xy).tap do |helipad|
              helipad.z = @airport.z
              helipad.length, helipad.width = dimensions_from($1)
            end
          end
        ].compact
      end

      def dimensions_from(text)
        dims = text.remove(/[^x\d.,]/i).split(/x/i).map { |s| s.to_ff.floor }
        case dims.size
        when 1
          [dim = AIXM.d(dims[0], :m), dim]
        when 2
          [AIXM.d(dims[0], :m), AIXM.d(dims[1], :m)]
        when 4
          [dim = AIXM.d(dims.min, :m), dim]
        else
          warn("bad dimensions for #{@airport.name}", pry: binding)
        end
      end

      def auw_weight_from(text)
        if wgt = text.match(/(\d+(?:[,.]\d+)?)\s*t/i)&.captures&.first
          AIXM.w(wgt.to_ff, :t)
        end
      end

      def lighting_from(text)
        return if text.blank? || text.match?(/nil|balisage\s*:\s*non/i)
        description = text.remove(/balisage\s*:|oui\.?\s*:?/i).compact.full_strip
        AIXM.lighting(position: :edge).tap do |lighting|
          lighting.description = description unless description.blank?
        end
      end

      def addresses_from(text, source)
        [].tap do |addresses|
          text.sub! /(?<!\p{L})t[ée]l\D*([\d\s.]{10,}(?:poste[\d\s.]{2,})?)[-\/]?/i do |m|
            addresses << AIXM.address(
              source: source,
              type: :phone,
              address: m.strip.sub(/poste/i, '-').remove(/[^\d-]|-$/)
            )
          end
          text.sub! /fax\D*([\d\s.]{10,}(?:poste[\d\s.]{2,})?)[-\/]?/i do |m|
            addresses << AIXM.address(
              source: source,
              type: :fax,
              address: m.strip.sub(/poste/i, '-').remove(/[^\d-]|-$/)
            )
          end
          text.sub! /e-mail\W*(\S+)[-\/]?/i do |m|
            addresses << AIXM.address(
              source: source,
              type: :email,
              address: m.strip
            )
          end
          text.sub! /(\d[\d\s]{9,}(?:poste[\d\s.]{2,})?)[-\/]?/i do |m|
            addresses << AIXM.address(
              source: source,
              type: :phone,
              address: m.strip.sub(/poste/i, '-').remove(/[^\d-]|-$/)
            )
          end
        end
      end

      patch AIXM::Feature::Airport, :xy do |parser, object, value|
        throw :abort if value.seconds?
        if xy = parser.fixture.dig(object.name, 'xy')
          lat, long = xy.split(/\s+/)
          AIXM.xy(lat: lat, long: long)
        else
          warn("coordinates for #{object.name} appear not to be exact", pry: binding)
          throw :abort
        end
      end

    end
  end
end
