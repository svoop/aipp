module AIPP
  module LF

    # Aerodromes radiocommunication facilities (VFR only)
    class AD16 < AIP

      include AIPP::LF::Helpers::Base
      include AIPP::LF::Helpers::RadioAD

      DEPENDS = %w(AD-1.3)

      DEFAULT_FREQUENCY = '123.5'

      ID_FIXES = {
        'LF04' => 'LF9004',   # illegal ID as per AIXM
        'LFPY' => nil         # decommissioned - see https://fr.wikipedia.org/wiki/Base_a%C3%A9rienne_217_Br%C3%A9tigny-sur-Orge
      }

      def parse
        document = prepare(html: read)
        document.css('tbody').each do |tbody|
          tbody.css('tr').group_by_chunks { _1.attr(:id).match?(/-TXT_NAME-/) }.each do |tr, trs|
            trs = Nokogiri::XML::NodeSet.new(document, trs)   # convert array to node set
            id = tr.css('span[id*="CODE_ICAO"]').text.cleanup
            next unless id = ID_FIXES.fetch(id, id)
            @airport = find_by(:airport, id: id).first
            addresses_from(trs).each { @airport.add_address(_1) }
            units_from(trs, airport: @airport).each(&method(:add))
          end
        end
        # Fallback to VAC or default A/A
        find_by(:airport).each do |airport|
          next if airport.units.any?
          next if airport.addresses.find_by(:address, type: :radio_frequency).any?
          pdf = read("VAC-#{airport.id}")
          if freq = pdf.text.first_match(/a\s*\/\s*a\D*([\d.\s]{3,})/i)
            airport.add_address AIXM.address(type: :radio_frequency, address: freq.remove(/0+$/).remove(/\s/))
          else
            warn("no radiocommunications assigned to #{airport.id}", pry: binding)
          end
        rescue OpenURI::HTTPError
          airport.add_address AIXM.address(type: :radio_frequency, address: DEFAULT_FREQUENCY)
        end
      end
    end

  end
end
