using AIXM::Refinements

module AIPP::LS::NOTAM
  class ENR < AIPP::NOTAM::Parser

    include AIPP::LS::Helpers::Base

    def parse
      json = read
      added_notam_ids = []
      json['queryNOTAMs'].each do |row|
        text = row['notamRaw']
        next unless text.match? /^Q\) LS/   # only parse national NOTAM
        notam = NOTAM.parse(text)
        if respect? notam
          next if notam.data[:five_day_schedules] == []
          added_notam_ids << notam.data[:id]
          add(
            case notam.data[:content]
            when /\A[DR].AREA.+ACT/, /TMA.+ACT/
              AIXM.generic(fragment: fragment_for(notam)).tap do |airspace|
                element = airspace.fragment.children.first
                element.find_or_add_child('txtRmk').content = notam.data[:translated_content]
                if schedule = notam.data[:five_day_schedules]
                  timetable = timetable_from(schedule)
                  element
                    .find_or_add_child('Att', before_css: %w(codeSelAvbl txtRmk))
                    .replace(timetable.to_xml(as: :Att).chomp)
                end
              end
            when /\ATEMPO [DR].AREA.+(?:ACT|EST)/
              airspace_from(notam)
            else
              airspace_from(notam)
            end
          )
        else
          verbose_info("Skipping NOTAM #{notam.data[:id]}")
        end
      end
      dabs_cross_check(added_notam_ids)
    end

    private

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
      when /[DR].AREA (?<name>LS-[DR]\d+[A-Z]?).+ACT/
        'Ase:has(codeId:matches("^%s( .+)?$"))' % [$~['name']]
      end.then do |selector|
        AIPP.cache.aip.at_css(selector, Nokogiri::MATCHES) or fail "no feature found for `#{notam.data[:content]}'"
      end
    end

    def airspace_from(notam)
      airspace = AIXM.airspace(
        id: notam.data[:id],
        type: :regulated_airspace,
        name: notam.data[:id]
      ).tap do |airspace|
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
      end
    end

    def geometry_from(text)

    end

    def obstacle_from(notam)
      # TODO: implement obstacle
    end

    def dabs_cross_check(added_notam_ids)
      dabs_date = aixm.effective_at.to_date.strftime("DABS Date: %Y %^B %d")
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
