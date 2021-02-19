module AIPP

  # Executable instantiated by the console tools
  class Executable
    attr_reader :options

    def initialize(**options)
      @options = options
      @options[:airac] = AIPP::AIRAC.new
      @options[:storage] = Pathname(Dir.home).join('.aipp')
      @options[:force] = @options[:mid] = false
      OptionParser.new do |o|
        o.banner = <<~END
          Download online AIP and convert it to #{options[:schema].upcase}.
          Usage: #{File.basename($0)} [options]
        END
        o.on('-d', '--airac DATE', String, %Q[AIRAC date (default: "#{@options[:airac].date.xmlschema}")]) { @options[:airac] = AIPP::AIRAC.new(_1) }
        o.on('-r', '--region STRING', String, 'region (e.g. "LF")') { @options[:region] = _1.upcase }
        o.on('-a', '--aip STRING', String, 'process this AIP only (e.g. "ENR-5.1")') { @options[:aip] = _1.upcase }
        if options[:schema] == :ofmx
          o.on('-g', '--[no-]grouped-obstacles', 'group obstacles (default: false)') { @options[:grouped_obstacles] = _1 }
          o.on('-m', '--[no-]mid', 'insert mid attributes into all Uid elements (default: false)') { @options[:mid] = _1 }
        end
        o.on('-s', '--storage DIR', String, 'storage directory (default: "~/.aipp")') { @options[:storage] = Pathname(_1) }
        o.on('-f', '--[no-]force', 'ignore XML schema validation (default: false)') { @options[:force] = _1 }
        o.on('-v', '--[no-]verbose', 'verbose output (default: false)') { $VERBOSE_INFO = _1 }
        o.on('-w', '--pry-on-warn [ID]', Integer, 'open pry on warn with ID (default: nil)') { $PRY_ON_WARN = _1 || true }
        o.on('-e', '--[no-]pry-on-error', 'open pry on error (default: false)') { $PRY_ON_ERROR = _1 }
        o.on('-A', '--about', 'show author/license information and exit') { about }
        o.on('-R', '--readme', 'show README and exit') { readme }
        o.on('-L', '--list', 'list implemented regions and AIPs') { list }
        o.on('-V', '--version', 'show version and exit') { version }
      end.parse!
    end

    # Load necessary files and execute the parser.
    #
    # @raise [RuntimeError] if the region does not exist
    def run
      Pry.rescue do
        fail(OptionParser::MissingArgument, :region) unless options[:region]
        starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        AIPP::Parser.new(options: options).tap do |parser|
          parser.read_config
          parser.read_region
          parser.parse_aip
          parser.validate_aixm
          parser.write_build
          parser.write_aixm
          parser.write_config
        end
        ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        puts "Finished after %s" % Time.at(ending - starting).utc.strftime("%H:%M:%S")
      rescue => error
        puts "ERROR: #{error.message}".magenta
        Pry::rescued(error) if $PRY_ON_ERROR
      end
    end

    private

    def about
      puts 'Written by Sven Schwyn (bitcetera.com) and distributed under MIT license.'
      exit
    end

    def readme
      readme_path = Pathname($0).dirname.join('..', 'gems', "aipp-#{AIPP::VERSION}", 'README.md')
      puts IO.read(readme_path)
      exit
    end

    def list
      regions_path = Pathname($0).dirname.join('..', 'gems', "aipp-#{AIPP::VERSION}", 'lib', 'aipp', 'regions')
      hash = Dir.each_child(regions_path).each.with_object({}) do |region, hash|
        hash[region] = Dir.children(regions_path.join(region)).sort.map do |aip|
          File.basename(aip, '.rb') if File.file?(regions_path.join(region, aip))
        end.compact
      end
      puts hash.to_yaml.sub(/\A\W*/, '')
      exit
    end

    def version
      puts AIPP::VERSION
      exit
    end
  end

end
