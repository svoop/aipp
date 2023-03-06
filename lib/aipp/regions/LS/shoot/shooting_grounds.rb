using AIXM::Refinements

module AIPP::LS::SHOOT
  class ShootingGrounds < AIPP::SHOOT::Parser

    include AIPP::LS::Helpers::Base

    DEFAULT_Z = AIXM.z(2000, :qfe)   # fallback if no max height is defined
    SAFETY = 100                     # safety margin in meters added to max height

    def parse
      effective_date = AIPP.options.local_effective_at.strftime('%Y%m%d')
      airac_date = AIRAC::Cycle.new(aixm.effective_at).to_s('%Y-%m-%d')
      shooting_grounds = {}
      read.each_with_index do |row, line|
        type, id, date, no_shooting = row[0], row[1], row[2], (row[17] == "1")
        next unless type == 'BSZ'
        next if no_shooting || date != effective_date
        next if AIPP.options.id && AIPP.options.id != id
        shooting_grounds[id] ||= read("shooting_grounds-#{id}")
          .fetch(:feature)
          .merge(
            csv_line: line,
            location_codes: row[5].split(/ *, */),   # TODO: currently ignored - not available as separate geometries
            details: row[6].blank_to_nil,
            url: row[10].blank_to_nil,
            upper_z: (AIXM.z(AIXM.d(row[15].to_i + SAFETY, :m).to_ft.dim.round, :qfe) if row[15]),
            dabs: (row[16] == '1'),
            schedules: []
          )
        shooting_grounds[id][:schedules] += schedules_for(row)
      end
      shooting_grounds.each do |id, data|
        data in csv_line:, location_codes:, details:, url:, upper_z:, schedules:, properties: { bezeichnung: name, infotelefonnr: phone, infoemail: email }
        if schedules.compact.any?
          geometries = geometries_for data[:geometry]
          indexed = geometries.count > 1
          geometries.each_with_index do |geometry, index|
            remarks = {
              details: details,
              phone: phone,
              email: email,
              bulletin: url
            }.to_remarks
            add(
              AIXM.airspace(
                source: "LS|OTHER|schiessgebiete.csv|#{airac_date}|#{csv_line}",
                region: 'LS',
                type: :dangerous_activities_area,
                name: "LS-S#{id} #{name} #{index if indexed}".strip
              ).tap do |airspace|
                airspace.add_layer layer_for(upper_z, schedules, remarks)
                airspace.geometry = geometry
                airspace.comment = "DABS: marked for publication"
              end
            )
          end
        end
      end
    end

    private

    def schedules_for(row)
      from, to = time_for(row[3]), time_for(row[4], ending: true)
      if from.to_date == to.to_date
        [
          [AIXM.date(from), (AIXM.time(from)..AIXM.time(to))]
        ]
      else
        [
          [AIXM.date(from), (AIXM.time(from)..AIXM::END_OF_DAY)],
          [AIXM.date(to), (AIXM::BEGINNING_OF_DAY..AIXM.time(to))]
        ]
      end
    end

    def time_for(string, ending: false)
      hour, min = case string.strip
      when /(\d{2})(\d{2})/
        [$1.to_i, $2.to_i]
      when '', '0'
        [0, 0]
      else
        warn("ignoring malformed time `#{string}'")
        [0, 0]
      end
      hour = 24 if hour.zero? && min.zero? && ending
      AIPP.options.local_effective_at.change(hour: hour, min: min).utc
    end

    def geometries_for(polygons)
      fail "only type MultiPolygon supported" unless polygons[:type] == 'MultiPolygon'
      fail "polygon coordinates missing" unless polygons[:coordinates]
      polygons[:coordinates].map do |(outer_polygon, inner_polygon)|
        warn "hole in polygon is ignored" if inner_polygon
        AIXM.geometry(
          *outer_polygon.map { AIXM.point(xy: AIXM.xy(long: _1.first , lat: _1.last)) }
        )
      end
    end

    def layer_for(upper_z, schedules, remarks)
      AIXM.layer(
        vertical_limit: AIXM.vertical_limit(
          upper_z: (upper_z || DEFAULT_Z),
          lower_z: AIXM::GROUND
        )
      ).tap do |layer|
        layer.activity = :shooting_from_ground
        layer.timetable = timetable_for(schedules)
        layer.remarks = remarks
      end
    end

    def timetable_for(schedules)
      AIXM.timetable.tap do |timetable|
        schedules.each do |(date, times)|
          timetable.add_timesheet(
            AIXM.timesheet(
              adjust_to_dst: true,
              dates: (date..date)
              # TODO: transform to...
              # dates: AIXM.date(date)
            ).tap do |timesheet|
              timesheet.times = times
            end
          )
        end
      end
    end

  end
end
