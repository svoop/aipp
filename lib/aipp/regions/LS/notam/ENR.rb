using AIXM::Refinements

module AIPP::LS::NOTAM
  class ENR < AIPP::NOTAM::Parser

    include AIPP::LS::Helpers::Base

    def parse
      AIPP.cache.aip ||= read('AIP').css('Ase')
      AIPP.cache.dabs ||= read('DABS')
      json = read
      fail "malformed JSON received from API" unless json.has_key?(:queryNOTAMs)
      added_notam_ids = []
      json[:queryNOTAMs].each do |row|
        next unless row[:notamRaw].match? /^Q\) LS/   # only parse national NOTAM

# HACK: try to add missing commas to D-item of A- and B-series NOTAM
# if row[:notamRaw].match? /\A[AB]/
#   if row[:notamRaw].gsub!(/(#{NOTAM::Schedule::HOUR_RE.decapture}-#{NOTAM::Schedule::HOUR_RE.decapture})/, '\1,')
#     row[:notamRaw].gsub!(/,+/, ',')
#     row[:notamRaw].sub!(/,\n/, "\n")
#     warn("HACK: added missing commas to D item")
#   end
# end

# HACK: remove braindead years from D-item of W-series NOTAM
if row[:notamRaw].match? /\AW/
  year = Time.now.year
  if row[:notamRaw].gsub!(/\s*(?:#{year}|#{year+1})\s*(#{NOTAM::Schedule::MONTH_RE})/, ' \1')
    warn("HACK: removed braindead years from D item")
  end
end

        (notam = notam_for(row[:notamRaw])) or next
        if respect? notam
          next if notam.data[:five_day_schedules] == []
          added_notam_ids << notam.data[:id]
          add(
            case notam.data[:content]
            when /\A[DR].AREA.+ACT/, /TMA.+ACT/
              if fragment = fragment_for(notam)
                AIXM.generic(fragment: fragment_for(notam)).tap do |airspace|
                  element = airspace.fragment.children.first
                  element.prepend_child(['<!--', notam.text ,'-->'].join("\n"))
                  content = ["NOTAM #{notam.data[:id]}", element.at_css('txtName').content].join(": ").strip
                  element.at_css('txtName').content = content
                  content = [element.at_css('txtRmk')&.text, notam.data[:translated_content]].join("\n").strip
                  element.find_or_add_child('txtRmk').content = content
                  if schedule = notam.data[:five_day_schedules]
                    timetable = timetable_from(schedule)
                    element
                      .find_or_add_child('Att', before_css: %w(codeSelAvbl txtRmk))
                      .replace(timetable.to_xml(as: :Att).chomp)
                  end
                end
              else
                warn "no feature found for `#{notam.data[:content]}' - fallback to point and radius"
                airspace_from(notam).tap do |airspace|
                  airspace.geometry = geometry_from_q_item(notam)
                end
              end
            when /\ATEMPO [DR].AREA.+(?:ACT|EST|ESTABLISHED) WI AREA/
              airspace_from(notam).tap do |airspace|
                airspace.geometry = geometry_from_content(notam)
              end
            else
              airspace_from(notam).tap do |airspace|
                airspace.geometry = geometry_from_q_item(notam)
              end
            end
          )
        else
          verbose_info("Skipping NOTAM #{notam.data[:id]}")
        end
      end
      dabs_cross_check(added_notam_ids)
    end

    private

    def notam_for(raw_notam)
      notam_id = raw_notam.strip.split(/\s+/, 2).first
      if AIPP.options.crossload
        crossload_file = AIPP.options.crossload.join('LS', "#{notam_id.sub('/', '_')}.txt")
        if File.exist? crossload_file
          info("crossloading #{crossload_file}")
          return NOTAM.parse(crossload_file.read)
        end
      end
      NOTAM.parse(raw_notam)
    rescue
      warn "cannot parse #{notam_id}"
      raise unless AIPP.options.force
    end

    # @return [Boolean] whether to respect this NOTAM or ignore it
    def respect?(notam)
      notam.data[:condition] != :checklist && (
        notam.data[:scope].include?(:navigation_warning) ||
        %i(terminal_control_area).include?(notam.data[:subject])   # TODO: include :obstacle as well
      )
    end

    def fragment_for(notam)
      case notam.data[:content]
      when /(?<type>TMA) ((SECT )?(?<section>\d+) )?ACT/
        'Ase:has(codeType:contains("%s") + codeId:contains("%s %s"))' % [$~['type'], notam.data[:locations].first, $~['section']]
      when /[DR].AREA LS-?(?<name>[DR]\d+[A-Z]?).+ACT/
        'Ase:has(codeId:matches("^LS%s( .+)?$"))' % [$~['name']]
      else
        return
      end.then do |selector|
        AIPP.cache.aip.at_css(selector, Nokogiri::MATCHES)
      end
    end

    def airspace_from(notam)
      AIXM.airspace(
        id: notam.data[:id],
        type: :regulated_airspace,
        name: "NOTAM #{notam.data[:id]}"
      ).tap do |airspace|
        airspace.add_layer(
          AIXM.layer(
            vertical_limit: AIXM.vertical_limit(
              upper_z: notam.data[:upper_limit],
              lower_z: notam.data[:lower_limit]
            )
          ).tap do |layer|
            layer.selective = true
            if schedule = notam.data[:five_day_schedules]
              layer.timetable = timetable_from(schedule)
            end
            layer.remarks = notam.data[:translated_content]
          end
        )
        airspace.comment = notam.text
      end
    end

    def geometry_from_content(notam)
      if notam.data[:content].squish.match(/WI AREA(?<coordinates>(?: \d{6}N\d{7}E)+)/)
        AIXM.geometry.tap do |geometry|
          $~['coordinates'].split.each do |coordinate|
            xy = AIXM.xy(lat: coordinate[0, 7], long: coordinate[7, 8])
            geometry.add_segment(AIXM.point(xy: xy))
          end
        end
      else
        warn "cannot parse WI AREA - fallback to point and radius"
        geometry_from_q_item(notam)
      end
    end

    def geometry_from_q_item(notam)
      AIXM.geometry.tap do |geometry|
        geometry.add_segment AIXM.circle(
          center_xy: notam.data[:center_point],
          radius: notam.data[:radius]
        )
      end
    end

    def obstacle_from(notam)
      # TODO: implement obstacle
    end

    def dabs_cross_check(added_notam_ids)
      dabs_date = aixm.effective_at.to_date.strftime("DABS Date: %Y %^b %d")
      case
      when AIPP.cache.dabs.nil?
        warn("DABS not available - skipping cross check")
      when !AIPP.cache.dabs.text.include?(dabs_date)
        warn("DABS date mismatch - skippping cross check")
      else
        dabs_notam_ids = AIPP.cache.dabs.text.scan(NOTAM::Item::ID_RE.decapture).uniq
        missing_notam_ids = dabs_notam_ids - added_notam_ids
        warn("DABS disagrees: #{missing_notam_ids.join(', ')} missing") if missing_notam_ids.any?
      end
    end

  end
end
