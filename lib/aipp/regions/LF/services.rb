module AIPP
  module LF

    class Services < AIP

      include AIPP::LF::Helpers::Base

      DEPENDS = %w(aerodromes serviced_airspaces)

      # Service types and how to treat them
      SOURCE_TYPES = {
        'A/A' => :address,
        'AFIS' => :service,
        'APP' => :service,
        'ATIS' => :service,
        'CCM' => :ignore,      # centre de contrôle militaire
        'CEV' => :ignore,      # centre d’essai en vol
        'D-ATIS' => :ignore,   # data link ATIS
        'FIS' => :service,
        'PAR' => :service,
        'SRE' => :ignore,      # surveillance radar element of PAR
        'TWR' => :service,
        'UAC' => :ignore,      # upper area control
        'VDF' => :service,
        'OTHER' => :service    # no <Service> specified at source
      }.freeze

      # Map French callsigns to English and service type
      CALLSIGNS = {
        'Approche' => { en: 'Approach', service_type: 'APP' },
        'Contrôle' => { en: 'Control', service_type: 'ACS' },
        'Information' => { en: 'Information', service_type: 'FIS' },
        'GCA' => { en: 'GCA', service_type: 'GCA' },
        'Gonio' => { en: 'Gonio', service_type: 'VDF' },
        'Prévol' => { en: 'Delivery', service_type: 'SMC' },
        'Sol' => { en: 'Ground', service_type: 'SMC' },
        'Tour' => { en: 'Tower', service_type: 'TWR' },
        'Trafic' => { en: 'Apron', service_type: 'SMC' }
      }.freeze

      def parse
        cache.service.css(%Q(Service[lk^="[LF]"][pk])).each do |service_node|
          # Ignore private services/frequencies
          next if service_node.(:IndicLieu) == 'XX'
          # Load referenced airport
          airport = given(service_node.at_css('Ad')&.attr('pk')) do
            find_by(:airport, meta: _1).first
          end
          # Build addresses and services
          case SOURCE_TYPES.fetch(type_for(service_node))
          when :address
            fail "dangling address without airport" unless airport
            addresses_from(service_node).each { airport.add_address(_1) }
          when :service
            given service_from(service_node) do |service|
              cache.frequence.css(%Q(Frequence:has(Service[pk="#{service_node['pk']}"]))).each do |frequence_node|
                if frequency = frequency_from(frequence_node, service_node)
                  service.add_frequency frequency
                end
              end
              if airport
                airport.add_unit(service.unit)
              end
              given service_node.at_css('Espace')&.attr('pk') do |espace_pk|
                find_by(:airspace, meta: espace_pk).each do |airspace|
                  airspace.layers.each { _1.add_service(service) }
                end
              end
            end
          end
        end
        # Assign fallback address (default A/A frequency) to all yet radioless airports
        find_by(:airport).each do |airport|
          unless airport.units.any? || airport.addresses.any?
            airport.add_address(fallback_address_for(airport.name))
          end
        end
      end

      private

      def type_for(service_node)
        SOURCE_TYPES.include?(type = service_node.(:Service)) ? type : 'OTHER'
      end

      def addresses_from(service_node)
        cache.frequence.css(%Q(Frequence:has(Service[pk="#{service_node['pk']}"]))).map do |frequence_node|
          if frequency = frequency_from(frequence_node, service_node)
            AIXM.address(
              type: :radio_frequency,
              address: frequency.transmission_f
            ).tap do |address|
              address.remarks = {
                'type' => service_node.(:Service),
                'indicatif/callsign' => frequency.callsigns.map { "#{_2} (#{_1})" }.join("/n")
              }.to_remarks
            end
          end
        end.compact
      end

      def fallback_address_for(callsign)
        AIXM.address(
          type: :radio_frequency,
          address: AIXM.f(123.5, :mhz)
        ).tap do |address|
          address.remarks = {
            'type' => 'A/A',
            'indicatif/callsign' => callsign
          }.to_remarks
        end
      end

      def service_from(service_node)
        service_type = CALLSIGNS.dig(service_node.(:IndicService), :service_type) || type_for(service_node)
        service = find_by(:service, type: service_type).first
        unit = service&.unit
        unless service
          service = AIXM.service(type: service_type)
          unit = find_by(:unit, name: service_node.(:IndicLieu), type: service.guessed_unit_type).first
          unless unit
            unit = AIXM.unit(
              source: source(section: 'GEN', position: service_node.line),
              organisation: organisation_lf,
              name: service_node.(:IndicLieu),
              type: service.guessed_unit_type,
              class: :icao
            )
            add unit
          end
          unit.add_service service
          service
        end
      end

      def frequency_from(frequence_node, service_node)
        frequency = frequence_node.(:Frequence).to_f
        case
        when frequency >= 137
          nil
        when frequency < 108
          warn("ignoring too low frequency `#{frequency}'", severe: false)
          nil
        else
          AIXM.frequency(
            transmission_f: AIXM.f(frequency, :mhz),
            callsigns: callsigns_from(service_node)
          ).tap do |frequency|
            frequency.timetable = timetable_from(frequence_node.(:HorCode))
            frequency.remarks = frequence_node.(:Remarque)
          end
        end
      end

      def callsigns_from(service_node)
        if service_node.(:IndicService) == '.'   # auto-information
          %i(fr en).to_h { [_1, '(auto)'] }
        else
          warn("language other than french") unless service_node.(:Langue) == 'fr'
          english = CALLSIGNS.fetch(service_node.(:IndicService)).fetch(:en)
          warn("no english translation for callsign `#{service_node.(:IndicService)}'") unless english
          {
            fr: "#{service_node.(:IndicLieu)} #{service_node.(:IndicService)}",
            en: ("#{service_node.(:IndicLieu)} #{english}" if english)
          }.compact
        end
      end

    end
  end
end
