module AIPP
  module SHOOT

    module Executable

      def options
        AIPP.options.merge(
          module: 'Shoot',
          local_effective_at: Time.now.at_midnight,
          id: nil
        )
      end

      def option_parser(o)
        o.banner = <<~END
          Download online shooting activities and convert them to #{AIPP.options.schema.upcase}.
          Usage: #{File.basename($0)} shoot [options]
        END
        o.on('-t', '--effective (DATE)', String, %Q[effective on this date (default: "#{AIPP.options.local_effective_at.to_date}")]) { AIPP.options.local_effective_at = Time.parse("#{_1} CET") }
        o.on('-i', '--id ID', String, %Q[process shooting ground with this ID only]) { AIPP.options.id = _1 }
      end

      def guard
        AIPP.options.time_zone = AIPP.options.local_effective_at.at_noon.strftime('%z')
        AIPP.options.effective_at = AIPP.options.local_effective_at.at_midnight.utc
      end

    end
  end
end
