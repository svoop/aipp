module AIPP

  # @abstract
  class Executable
    include AIPP::Debugger

    def initialize(exe_file)
      require_scope
      AIPP.options.replace(
        scope: scope,
        schema: exe_file.split('2').last.to_sym,
        storage: Pathname(Dir.home).join('.aipp'),
        clean: false,
        force: false,
        mid: false,
        quiet: false,
        verbose: false,
        debug_on_warning: false,
        debug_on_error: false
      )
      options
      OptionParser.new do |o|
        o.on('-r', '--region STRING', String, 'region (e.g. "LF")') { AIPP.options.region = _1.upcase }
        o.on('-s', '--section STRING', String, 'process this section only') { AIPP.options.section = _1.classify }
        o.on('-d', '--storage DIR', String, 'storage directory (default: "~/.aipp")') { AIPP.options.storage = Pathname(_1) }
        o.on('-o', '--output FILE', String, 'output file') { AIPP.options.output_file = _1 }
        option_parser(o)
        if AIPP.options.schema == :ofmx
          o.on('-m', '--[no-]mid', 'insert mid attributes into all Uid elements (default: false)') { AIPP.options.mid = _1 }
        end
        o.on('-h', '--[no-]check-links', 'check all links with HEAD requests') { AIPP.options.check_links = _1 }
        o.on('-c', '--[no-]clean', 'clean cache and download from sources anew (default: false)') { AIPP.options.clean = _1 }
        o.on('-f', '--[no-]force', 'continue on non-fatal errors (default: false)') { AIPP.options.force = _1 }
        o.on('-q', '--[no-]quiet', 'suppress all informational output (default: false)') { AIPP.options.quiet = _1 }
        o.on('-v', '--[no-]verbose', 'verbose output including unsevere warnings (default: false)') { AIPP.options.verbose = _1 }
        o.on('-w', '--debug-on-warning [ID]', Integer, 'open debug session on warning with ID (default: false)') { AIPP.options.debug_on_warning = _1 || true }
        o.on('-e', '--[no-]debug-on-error', 'open debug session on error (default: false)') { AIPP.options.debug_on_error = _1 }
        o.on('-A', '--about', 'show author/license information and exit') { about }
        o.on('-R', '--readme', 'show README and exit') { readme }
        o.on('-L', '--list', 'list implemented regions') { list }
        o.on('-V', '--version', 'show version and exit') { version }
      end.parse!
    end

    def run
      with_debugger do
        String.disable_colorization = !STDOUT.tty?
        starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        [:AIPP, AIPP.options.scope, :Runner].constantize.new.run
        ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        info("finished after %s" % Time.at(ending - starting).utc.strftime("%H:%M:%S"))
      end
    end

    private

    def about
      puts 'Written by Sven Schwyn (bitcetera.com) and distributed under MIT license.'
      exit
    end

    def readme
      puts IO.read(Pathname(__dir__).join('README.md'))
      exit
    end

    def list
      puts "Available scopes -> regions -> sections:"
      lib_dir.join('scopes').each_child do |scope_dir|
        next unless scope_dir.directory?
        puts "\n#{scope_dir.basename} ->".upcase
        lib_dir.join('regions').each_child do |region_dir|
          next unless region_dir.directory? && region_dir.join(scope_dir.basename).exist?
          puts "  #{region_dir.basename} ->"
          region_dir.join(scope_dir.basename).glob('*.rb') do |section_file|
            puts "    #{section_file.basename('.rb')}"
          end
        end
      end
      exit
    end

    def version
      puts AIPP::VERSION
      exit
    end

    def lib_dir
      Pathname(__FILE__).dirname
    end

    def scope
      @scope ||= ARGV.first.match?(/^-/) ? 'AIP' : ARGV.shift.upcase
    end

    def require_scope
      lib_dir.join('scopes', scope.downcase).glob('*.rb').each { require _1 }
      extend [:AIPP, scope, :Executable].constantize
    end
  end
end
