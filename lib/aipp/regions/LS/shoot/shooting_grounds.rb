using AIXM::Refinements

module AIPP::LS::SHOOT
  class ShootingGrounds < AIPP::SHOOT::Parser

    include AIPP::LS::Helpers::Base

    DEFAULT_Z = AIXM.z(1000, :qfe)   # height 300m unless present in publication

    def parse
      effective_date = aixm.effective_at.strftime('%Y%m%d')
      airac_date = AIRAC::Cycle.new(aixm.effective_at).to_s('%Y-%m-%d')
      shooting_grounds = {}
      read.each_with_index do |row, line|
        type, id, date, no_shooting = row[0], row[1], row[2], (row[17] == "1")
        if type == 'BSZ' && !no_shooting && date == effective_date
          shooting_grounds[id] ||= read("shooting_grounds-#{id}")
            .fetch(:feature)
            .merge(
              csv_line: line,
              location_codes: row[5].split(/ *, */),   # TODO: currently ignored - not available as separate geometries
              details: row[6].blank_to_nil,
              url: row[10].blank_to_nil,
              upper_z: (AIXM.z(AIXM.d(row[15].to_i, :m).to_ft.dim.round, :qfe) if row[15]),
              dabs: (row[16] == '1'),
              schedules: []
            )
          shooting_grounds[id][:schedules] << schedule_for(row)
        end
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

    # Returns +nil+ if neither beginning nor ending time is declared which
    # has to be treated as "no shooting".
    def schedule_for(row)
      from = AIXM.time("#{row[3]} #{AIPP.options.time_zone}") if row[3]
      to = AIXM.time("#{row[4]} #{AIPP.options.time_zone}") if row[4]
      case
        when from && to then (from..to)
        when from then (from..AIXM::END_OF_DAY)
        when to then (AIXM::BEGINNING_OF_DAY..to)
      end
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
        schedules.each do |schedule|
          timetable.add_timesheet(
            AIXM.timesheet(
              adjust_to_dst: true,
              dates: (AIXM.date(aixm.effective_at)..AIXM.date(aixm.effective_at))
              # TODO: transform to...
              # dates: AIXM.date(aixm.effective_at)
            ).tap do |timesheet|
              timesheet.times = schedule
            end
          )
        end
      end
    end

  end
end