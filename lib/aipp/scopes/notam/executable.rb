module AIPP
  module NOTAM

    module Executable

      def options
        AIPP.options.merge(
          module: 'NOTAM',
          effective_at: Time.now.change(min: 0, sec: 0)
        )
      end

      def option_parser(o)
        o.banner = <<~END
          Download online NOTAM and convert it to #{AIPP.options.schema.upcase}.
          Usage: #{File.basename($0)} notam [options]
        END
        o.on('-t', '--effective (TIME)', String, %Q[effective at this time (default: "#{AIPP.options.effective_at}")]) { AIPP.options.effective_at = Time.parse(_1) }
        o.on('-x', '--crossload DIR', String, 'crossload directory') { AIPP.options.crossload = Pathname(_1) }
      end

      def guard
        AIPP.options.effective_at = AIPP.options.effective_at.change(min: 0, sec: 0).utc
      end

    end
  end
end
