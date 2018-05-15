module AIPP
  module LF
    class ENR41 < AIP
      using AIPP::Refinements

      def parse
        html.css('tbody').each do |tbody|
          tbody.css('tr').to_enum.with_index(1).each do |tr, index|
            tds = cleanup(node: tr).css('td')
            master, slave = tds[1].text.strip.gsub(/[^\w-]/, '').downcase.split('-')
            navaid = AIXM.send(master, base_from(tds).merge(send("#{master}_from", tds)))
            navaid.region = 'LF'
            navaid.source = source_for(tr)
            navaid.timetable = timetable_from(tds[4])
            navaid.remarks = remarks_from(tds[5], tds[7], tds[9])
            navaid.send("associate_#{slave}", channel: channel_from(tds[3])) if slave
            aixm.features << navaid
          rescue => exception
            warn("error parsing navigational aid at ##{index}: #{exception.message}", binding)
          end
        end
      end

      private

      def source_for(tr)
        ['LF', 'ENR', 'ENR-4.1', options[:airac].date.xmlschema, line(node: tr)].join('|')
      end

      def base_from(tds)
        {
          organisation: organisation_lf,
          id: tds[2].text.strip,
          name: tds[0].text.strip,
          xy: xy_from(tds[5]),
          z: z_from(tds[6])
        }
      end

      def vor_from(tds)
        {
          type: :conventional,
          f: frequency_from(tds[3]),
          north: :magnetic,
        }
      end

      def dme_from(tds)
        {
          channel: channel_from(tds[3])
        }
      end

      def ndb_from(tds)
        {
          type: :en_route,
          f: frequency_from(tds[3])
        }
      end

      def tacan_from(tds)
        {
          channel: channel_from(tds[3])
        }
      end

      def xy_from(td)
        parts = td.text.strip.split(/\s+/)
        AIXM.xy(lat: parts[0], long: parts[1])
      end

      def z_from(td)
        parts = td.text.strip.split(/\s+/)
        AIXM.z(parts[0].to_i, :qnh) if parts[1] == 'ft'
      end

      def frequency_from(td)
        parts = td.text.strip.split(/\s+/)
        AIXM.f(parts[0].to_f, parts[1]) if parts[1] =~ /hz$/i
      end

      def channel_from(td)
        parts = td.text.strip.split(/\s+/)
        parts.last if parts[-2].downcase == 'ch'
      end

      def timetable_from(td)
        code = td.text.strip
        AIXM.timetable(code: code) unless code.empty?
      end

      def remarks_from(*parts)
        part_titles = ['RANGE', 'SITUATION', 'OBSERVATIONS']
        [].tap do |remarks|
          parts.each.with_index do |part, index|
            text = if index == 0
              part = part.text.strip.split(/\s+/)
              part.shift(2)
              part.join(' ').blank_to_nil
            else
              part.text.strip.blank_to_nil
            end
            remarks << "#{part_titles[index]}:\n#{text}" if text
          end
        end.join("\n\n").blank_to_nil
      end
    end
  end
end
