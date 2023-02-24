module AIPP
  module SHOOT

    module Executable

      def options
        AIPP.options.merge(
          module: 'Shoot',
          effective_at: Time.now.at_midnight
        )
      end

      def option_parser(o)
        o.banner = <<~END
          Download online shooting activities and convert them to #{AIPP.options.schema.upcase}.
          Usage: #{File.basename($0)} shoot [options]
        END
        o.on('-t', '--effective (DATE)', String, %Q[effective on this date (default: "#{AIPP.options.effective_at.to_date}")]) { AIPP.options.effective_at = Time.parse("#{_1} CET") }
      end

      def guard
        AIPP.options.time_zone = AIPP.options.effective_at.at_noon.strftime('%z')
        AIPP.options.effective_at = AIPP.options.effective_at.at_midnight.utc
      end

    end
  end
end
