module AIPP::LS::NOTAM
  class ENR < AIPP::NOTAM::Parser

    include AIPP::LS::Helpers::Base

    def parse
      xml = read
      xml.css('row').each do |row|
        column = row.css('column[name="notam"]')
        text = JSON.parse(column.text.gsub(/\n/, '\\n')).fetch('all')
        notam = NOTAM.parse(text)
        airspace = AIXM.airspace(
          id: notam.data[:id],
          type: :regulated_airspace,
          name: notam.data[:id]
        )
        airspace.add_layer(
          AIXM.layer(
            vertical_limit: AIXM.vertical_limit(
              upper_z: notam.data[:upper_limit],
              lower_z: notam.data[:lower_limit]
            )
          )
        )
        airspace.geometry.add_segment(
          AIXM.circle(
            center_xy: notam.data[:center_point],
            radius: notam.data[:radius]
          )
        )
        airspace.comment = notam.text
        add airspace
      end
    end

  end
end
