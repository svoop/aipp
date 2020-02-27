module AIPP
  module LF

    # ENR Navaids
    class ENR41 < AIP

      include AIPP::LF::Helpers::Base
      include AIPP::LF::Helpers::NavigationalAid

      def parse
        prepare(html: read).css('tbody').each do |tbody|
          tbody.css('tr').to_enum.with_index(1).each do |tr, index|
            tds = tr.css('td')
            navigational_aid = navigational_aid_from(
              {
                name: tds[0],
                type: tds[1],
                id: tds[2],
                f: tds[3],
                schedule: tds[4],
                xy: tds[5],
                z: tds[6]
              },
              source: source(position: tr.line),
              sections: {
                range: tds[5].css('span[id*="PORTEE"], span[id*="COUVERTURE"]'),
                situation: tds[7],
                observations: tds[9]
              }
            )
            if navigational_aid && aixm.features.find_by(navigational_aid.class, id: navigational_aid.id, xy: navigational_aid.xy).none?
              add navigational_aid
            end
          rescue => error
            warn("error parsing navigational aid at ##{index}: #{error.message}", pry: error)
          end
        end
      end
    end
  end
end
