module AIPP

  # Executable instantiated by the console tools
  class Executable
    include AIPP::Debugger

    attr_reader :options

    def initialize(**options)
      @options = options.merge(
        airac: AIRAC::Cycle.new,
        region_options: [],
        storage: Pathname(Dir.home).join('.aipp'),
        force: false,
        mid: false,
        verbose: false,
        debug_on_warning: false,
        debug_on_error: false
      )
      OptionParser.new do |o|
        o.banner = <<~END
          Download online AIP and convert it to #{options[:schema].upcase}.
          Usage: #{File.basename($0)} [options]
        END
        o.on('-d', '--airac (DATE|INTEGER)', String, %Q[AIRAC date or delta e.g. "+1" (default: "#{@options[:airac].date.xmlschema}")]) { @options[:airac] = airac_for(_1) }
        o.on('-r', '--region STRING', String, 'region (e.g. "LF")') { @options[:region] = _1.upcase }
        o.on('-a', '--aip STRING', String, 'process this AIP only (e.g. "ENR-5.1")') { @options[:aip] = _1 }
        if options[:schema] == :ofmx
          o.on('-g', '--[no-]grouped-obstacles', 'group obstacles (default: false)') { @options[:grouped_obstacles] = _1 }
          o.on('-m', '--[no-]mid', 'insert mid attributes into all Uid elements (default: false)') { @options[:mid] = _1 }
        end
        o.on('-o', '--region-options STRING', String, %Q[comma separated region specific options]) { @options[:region_options] = _1.split(',') }
        o.on('-s', '--storage DIR', String, 'storage directory (default: "~/.aipp")') { @options[:storage] = Pathname(_1) }
        o.on('-h', '--[no-]check-links', 'check all links with HEAD requests') { @options[:check_links] = _1 }
        o.on('-f', '--[no-]force', 'ignore XML schema validation (default: false)') { @options[:force] = _1 }
        o.on('-v', '--[no-]verbose', 'verbose output including unsevere warnings (default: false)') { @options[:verbose] = _1 }
        o.on('-w', '--debug-on-warning [ID]', Integer, 'open debug session on warning with ID (default: false)') { @options[:debug_on_warning] = _1 || true }
        o.on('-e', '--[no-]debug-on-error', 'open debug session on error (default: false)') { @options[:debug_on_error] = _1 }
        o.on('-A', '--about', 'show author/license information and exit') { about }
        o.on('-R', '--readme', 'show README and exit') { readme }
        o.on('-L', '--list', 'list implemented regions and AIPs') { list }
        o.on('-V', '--version', 'show version and exit') { version }
      end.parse!
    end

    def run
      with_debugger(**options.slice(:verbose, :debug_on_warning, :debug_on_error)) do
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
        info("finished after %s" % Time.at(ending - starting).utc.strftime("%H:%M:%S"))
      end
    end

    private

    def airac_for(argument)
      if argument.match?(/^[+-]\d+$/)   # delta
        AIRAC::Cycle.new + argument.to_i
      else   # date
        AIRAC::Cycle.new(argument)
      end
    end

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
