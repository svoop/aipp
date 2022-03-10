module AIPP

  # @abstract
  class Executable
    include AIPP::Debugger

    def initialize(exe_file)
      AIPP.options.replace(
        schema: exe_file.split('2').last.to_sym,
        storage: Pathname(Dir.home).join('.aipp'),
        clean: false,
        force: false,
        mid: false,
        verbose: false,
        debug_on_warning: false,
        debug_on_error: false
      )
    end

    def run
      with_debugger do
        starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        [:AIPP, AIPP.options.module, :Runner].constantize.new.run
        ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        info("finished after %s" % Time.at(ending - starting).utc.strftime("%H:%M:%S"))
      end
    end

    private

    def common_options(o)
      o.on('-r', '--region STRING', String, 'region (e.g. "LF")') { AIPP.options.region = _1.upcase }
      o.on('-s', '--section STRING', String, 'process this section only') { AIPP.options.section = _1.classify }
      o.on('-d', '--storage DIR', String, 'storage directory (default: "~/.aipp")') { AIPP.options.storage = Pathname(_1) }
    end

    def developer_options(o)
      if AIPP.options.schema == :ofmx
        o.on('-m', '--[no-]mid', 'insert mid attributes into all Uid elements (default: false)') { AIPP.options.mid = _1 }
      end
      o.on('-h', '--[no-]check-links', 'check all links with HEAD requests') { AIPP.options.check_links = _1 }
      o.on('-c', '--[no-]clean', 'clean cache and download from sources anew (default: false)') { AIPP.options.clean = _1 }
      o.on('-f', '--[no-]force', 'ignore XML schema validation (default: false)') { AIPP.options.force = _1 }
      o.on('-v', '--[no-]verbose', 'verbose output including unsevere warnings (default: false)') { AIPP.options.verbose = _1 }
      o.on('-w', '--debug-on-warning [ID]', Integer, 'open debug session on warning with ID (default: false)') { AIPP.options.debug_on_warning = _1 || true }
      o.on('-e', '--[no-]debug-on-error', 'open debug session on error (default: false)') { AIPP.options.debug_on_error = _1 }
      o.on('-A', '--about', 'show author/license information and exit') { about }
      o.on('-R', '--readme', 'show README and exit') { readme }
      o.on('-L', '--list', 'list implemented regions') { list }
      o.on('-V', '--version', 'show version and exit') { version }
    end

    def about
      puts 'Written by Sven Schwyn (bitcetera.com) and distributed under MIT license.'
      exit
    end

    def readme
      puts IO.read(Pathname(__dir__).join('README.md'))
      exit
    end

    def list
      hash = Pathname(__dir__).join('regions').glob('*').each.with_object({}) do |dir, hash|
        region = "Sections for region #{dir.basename}"
        hash[region] = dir.join(AIPP.options.module.downcase).glob('*.rb').map do |file|
          File.basename(file, '.rb')
        end.compact
      end
      puts hash.to_yaml.lines[1..]
      exit
    end

    def version
      puts AIPP::VERSION
      exit
    end

  end
end
