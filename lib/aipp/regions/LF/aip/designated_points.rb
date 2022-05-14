module AIPP::LF::AIP
  class DesignatedPoints < AIPP::AIP::Parser

    include AIPP::LF::Helpers::Base

    depends_on :Aerodromes

    SOURCE_TYPES = {
      'VFR' => :vfr_reporting_point,
      'WPT' => :icao
    }.freeze

    def parse
      SOURCE_TYPES.each do |source_type, type|
        verbose_info("processing #{source_type}")
        AIPP.cache.navfix.css(%Q(NavFix[lk^="[LF][#{source_type} "])).each do |navfix_node|
          ident = navfix_node.(:Ident)
          add(
            AIXM.designated_point(
              source: source(part: 'ENR', position: navfix_node.line),
              type: type,
              id: ident.split('-').last.remove(/[^a-z\d]/i),   # only use last segment of ID
              name: ident,
              xy: xy_from(navfix_node.(:Geometrie))
            ).tap do |designated_point|
              designated_point.remarks = navfix_node.(:Description)
              if ident.match? /-/
                airport = find_by(:airport, id: "LF#{ident.split('-').first}").first
                designated_point.airport = airport
              end
            end
          )
        end
      end
      AIXM::Concerns::Memoize.method :to_uid do
        aixm.features.find_by(:designated_point).duplicates.each do |duplicates|
          duplicates.first.name += '/' + duplicates[1..].map(&:name).join('/')
          aixm.remove_features(duplicates[1..])
        end
      end
    end

  end
end
