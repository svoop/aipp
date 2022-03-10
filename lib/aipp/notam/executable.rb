module AIPP
  module NOTAM

    class Executable < AIPP::Executable

      def initialize(exe_file)
        super
        AIPP.options.merge(
          module: 'NOTAM',
          effective_at: Time.now.beginning_of_hour + 3600
        )
        OptionParser.new do |o|
          o.banner = <<~END
            Download online NOTAM and convert it to #{AIPP.options.schema.upcase}.
            Usage: #{File.basename($0)} [options]
          END
          common_options(o)
          o.on('-t', '--effective (TIME)', String, %Q[effective after this point in time (default: #{AIPP.options.effective_at})]) { AIPP.options.effective_at = Time.parse(_1) }
          developer_options(o)
        end.parse!
      end

    end
  end
end
