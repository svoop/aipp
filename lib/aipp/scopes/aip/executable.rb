module AIPP
  module AIP

    module Executable

      def options
        AIPP.options.merge(
          scope: 'AIP',
          airac: AIRAC::Cycle.new,
          region_options: []
        )
      end

      def option_parser(o)
        o.banner = <<~END
          Download online AIP and convert it to #{AIPP.options.schema.upcase}.
          Usage: #{File.basename($0)} [options]
        END
        o.on('-a', '--airac (DATE|INTEGER)', String, %Q[AIRAC date or delta e.g. "+1" (default: "#{AIPP.options.airac.date.xmlschema}")]) { AIPP.options.airac = airac_for(_1) }
        if AIPP.options.schema == :ofmx
          o.on('-g', '--[no-]grouped-obstacles', 'group obstacles (default: false)') { AIPP.options.grouped_obstacles = _1 }
        end
        o.on('-O', '--region-options STRING', String, %Q[comma separated region specific options]) { AIPP.options.region_options = _1.split(',') }
      end

      private

      def airac_for(argument)
        if argument.match?(/^[+-]\d+$/)   # delta
          AIRAC::Cycle.new + argument.to_i
        else   # date
          AIRAC::Cycle.new(argument)
        end
      end

    end
  end
end
