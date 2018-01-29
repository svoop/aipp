module AIPP
  module Parsers
    include Helpers::URL
    include Helpers::HTML
    using AIPP::Refinements

    MASTER_MAP = {
      'l' => 'ndb'
    }.freeze

    def convert!
      cleanup!
      html.css('tbody').each do |tbody|
        name = last_id = nil
        tbody.css('tr').to_enum.with_index(1).each do |tr, index|
          break if index >= @limit
          case tr.attr(:id)
          when /TXT_NAME/
            index -= 1
            name = tr.css('td').text.strip.split("\n").first
          when /GEO_LAT/
            tds = tr.css('td')
            type, runway = tds[0].text.strip.gsub(/\s+/, ' ').split(' ', 2)
            master, slave = type.downcase.split('-')
            if respond_to?("#{master}_from", true)
              id = tds[1].text.strip.blank_to_nil || last_id
              navaid = AIXM.send(
                (MASTER_MAP[master] || master),
                { id: id, name: [name, runway].compact.join(' ') }.
                  merge(base_from(tds)).
                  merge(send("#{master}_from", tds))
              )
              navaid.schedule = schedule_from(tds[3])
              navaid.remarks = remarks_from(tds[6], tds[7], tds[8])
              navaid.send("associate_#{slave}", channel: channel_from(tds[2])) if slave
              aixm.features << navaid
              last_id = id
            else
              warn("WARNING: navigational aid `#{master}' at ##{index} skipped: not relevant to VFR")
            end
          end
        rescue => exception
          warn("WARNING: error parsing navigational aid at ##{index}: #{exception.message}", binding)
        end
      end
      true
    end

    private

    def base_from(tds)
      {
        xy: xy_from(tds[4]),
        z: z_from(tds[5])
      }
    end

    def vor_from(tds)
      {
        type: :conventional,
        f: frequency_from(tds[2]),
        north: :geographic,
      }
    end

    def dme_from(tds)
      {
        channel: channel_from(tds[2])
      }
    end

    def ndb_from(tds)
      {
        type: :en_route,
        f: frequency_from(tds[2])
      }
    end

    def l_from(tds)
      {
        type: :locator,
        f: frequency_from(tds[2])
      }
    end

    def tacan_from(tds)
      {
        channel: channel_from(tds[2])
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
      AIXM.f(parts[0], parts[1]) if parts[1] =~ /hz$/i
    end

    def channel_from(td)
      parts = td.text.strip.split(/\s+/)
      parts.last if parts[-2].downcase == 'ch'
    end

    def schedule_from(td)
      code = td.text.strip
      AIXM.schedule(code: code) unless code.empty?
    end

    def remarks_from(*parts)
      part_titles = ['COVERAGE', 'RDH (SLOPE)', 'LOCATION']
      [].tap do |remarks|
        parts.each.with_index do |part, index|
          if part = part.text.gsub(/ +/, ' ').strip.blank_to_nil
            remarks << "#{part_titles[index]}:\n#{part}"
          end
        end
      end.join("\n\n").blank_to_nil
    end
  end
end
