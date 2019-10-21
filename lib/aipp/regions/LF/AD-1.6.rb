module AIPP
  module LF

    # Aerodromes radiocommunication facilities (VFR only)
    class AD16 < AIP

      include AIPP::LF::Helpers::Base
      include AIPP::LF::Helpers::RadioAD

      DEPENDS = %w(AD-1.3)

      ID_FIXES = {
        'LF04' => 'LF9004',   # illegal ID as per AIXM
        'LFPY' => nil         # decommissioned - see https://fr.wikipedia.org/wiki/Base_a%C3%A9rienne_217_Br%C3%A9tigny-sur-Orge
      }

      def parse
        prepare(html: read).css('tbody').first do |tbody|
          tbody.css('tr').group_by_chunks { |e| e.attr(:id).match?(/-TXT_NAME-/) }.each do |tr, trs|
            id = tr.css('span[id*="CODE_ICAO"]').text.cleanup
            next unless id = ID_FIXES.fetch(id, id)
            @airport = select(:airport, id: id).first
            addresses_from(trs).each { |a| @airport.add_address(a) }
            units_from(trs).each(&method(:add))
          end
        end
      end

    end
  end
end
