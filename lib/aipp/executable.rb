module AIPP

  # Executable instantiated by the console tools
  class Executable
    attr_reader :options

    def initialize(**options)
      @options = options
      @options[:airac] = AIPP::AIRAC.new
      @options[:storage] = Pathname(Dir.home).join('.aipp')
      @options[:pry_on_warn] = @options[:pry_on_error] = false
      OptionParser.new do |o|
        o.banner = <<~END
          Download online AIP and convert it to #{options[:schema].upcase}.
          Usage: #{File.basename($0)} [options]
        END
        o.on('-A', '--about', 'show author/license information and exit') { about }
        o.on('-R', '--readme', 'show README and exit') { readme }
        o.on('-d', '--airac DATE', String, 'AIRAC date (e.g. "2018-01-04", default: current)') { |v| @options[:airac] = AIPP::AIRAC.new(v) }
        o.on('-r', '--region STRING', String, 'region (e.g. "LF")') { |v| @options[:region] = v.upcase }
        o.on('-a', '--aip STRING', String, 'process this AIP only (e.g. "ENR-5.1")') { |v| @options[:aip] = v.upcase }
        o.on('-s', '--storage DIR', String, 'storage directory (default: ~/.aipp)') { |v| @options[:storage] = Pathname(v) }
        o.on('-p', '--[no-]pry-on-warn', 'open pry session on warn (default: false)') { |v| @options[:pry_on_warn] = v }
        o.on('-P', '--[no-]pry-on-error', 'open pry session on error (default: false)') { |v| @options[:pry_on_error] = v }
        o.on('-v', '--version', 'show version and exit') { version }
      end.parse!
      fail(OptionParser::MissingArgument, :region) unless @options[:region]
    end

    # Load necessary files and execute the parser.
    #
    # @raise [RuntimeError] if the region does not exist
    def run
      (dir = Pathname(__dir__).join('regions', options[:region])).exist? or fail("unknown region")
      dir.glob('*.rb').each { |f| require f }
      AIPP::Parser.new(options: options).tap do |parser|
        parser.read_config
        parser.download_html
        parser.parse_html
        parser.validate_aixm
        parser.write_aixm
        parser.write_config
      end
    rescue => error
      puts "ERROR: #{error.message}"
      binding.pry if options[:pry_on_error] && binding.respond_to?(:pry)
    end

    private

    def about
      puts 'Written by Sven Schwyn (bitcetera.com) and distributed under MIT license.'
      exit
    end

    def readme
      puts IO.read("#{File.dirname($0)}/../gems/aipp-#{AIPP::VERSION}/README.md")
      exit
    end

    def version
      puts AIPP::VERSION
      exit
    end
  end

end
