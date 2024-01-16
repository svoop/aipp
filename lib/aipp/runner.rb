module AIPP

  # @abstract
  class Runner
    include AIPP::Debugger
    using AIXM::Refinements

    # @return [AIXM::Document] target document
    attr_reader :aixm

    def initialize
      AIPP.options.storage = AIPP.options.storage.join(AIPP.options.region, AIPP.options.scope.downcase)
      AIPP.options.storage.mkpath
      @dependencies = THash.new
      @aixm = AIXM.document(effective_at: effective_at, expiration_at: expiration_at)
      AIXM.send("#{AIPP.options.schema}!")
      AIXM.config.region = AIPP.options.region
    end

    # @return [String]
    def inspect
      "#<#{self.class}>"
    end

    # @abstract
    def effective_at
      fail "effective_at method must be implemented by module runner"
    end

    # @abstract
    def expiration_at
      nil
    end

    # @abstract
    def run
      fail "run method must be implemented by module runner"
    end

    # @return [Pathname] directory containing all files for the current region
    def region_dir
      Pathname(__FILE__).dirname.join('regions', AIPP.options.region)
    end

    # @return [String] sources file name (default: xmlschema representation
    #   of effective_at date/time)
    def sources_file
      effective_at.xmlschema
    end

    def output_file
      "#{AIPP.options.region}_#{AIPP.options.scope}_#{effective_at.strftime('%F_%HZ')}.#{AIPP.options.schema}"
    end

    # @return [Pathname] directory containing the builds
    def builds_dir
      AIPP.options.storage.join('builds')
    end

    # @return [Pathname] config file for the current region
    def config_file
      AIPP.options.storage.join('config.yml')
    end

    private

    # Read the configuration from config.yml.
    def read_config
      info("using gem aipp-#{AIPP::VERSION}")
      info("reading config.yml")
      AIPP.config.read! config_file
      @aixm.namespace = AIPP.config.namespace
    end

    # Read the region directory.
    def read_region
      info("reading region #{AIPP.options.region}")
      fail("unknown region `#{AIPP.options.region}'") unless region_dir.exist?
      verbose_info "reading fixtures"
      AIPP.fixtures.read! region_dir.join('fixtures')
      verbose_info "reading borders"
      AIPP.borders.read! region_dir.join('borders')
      verbose_info "reading helpers"
      region_dir.glob('helpers/*.rb').each { |f| require f }
    end

    # Read parser files.
    def read_parsers
      verbose_info("reading parsers")
      region_dir.join(AIPP.options.scope.downcase).glob('*.rb').each do |file|
        verbose_info "requiring #{file.basename}"
        require file
        section = file.basename('.*').to_s.classify
        @dependencies[section] = class_for(section).dependencies
      end
    end

    # Parse sections by invoking the parser classes.
    def parse_sections
      AIPP::Downloader.new(storage: AIPP.options.storage, source: sources_file) do |downloader|
        @dependencies.tsort(AIPP.options.section).each do |section|
          info("parsing #{section.sectionize}")
          class_for(section).new(
            downloader: downloader,
            aixm: aixm
          ).attach_patches.tap(&:parse).detach_patches
        end
      end
    end

    # Validate the AIXM document.
    #
    # @raise [RuntimeError] if the document is not valid
    def validate_aixm
      info("detecting duplicates")
      if (duplicates = aixm.features.duplicates).any?
        message = "duplicates found"
        details = duplicates.map { "#{_1.inspect} from #{_1.source}" }.join("\n")
        AIPP.options.force ? warn(message) : fail([message, details].join(":\n"))
      end
      info("validating #{AIPP.options.schema.upcase}")
      unless aixm.valid?
        message = "invalid #{AIPP.options.schema.upcase} document"
        details = aixm.errors.map(&:message).join("\n")
        AIPP.options.force ? warn(message) : fail([message, details].join(":\n"))
      end
      info("counting #{aixm.features.count} feature(s)")
    end

    # Write the AIXM document.
    def write_aixm(file)
      if aixm.features.any? || AIPP.options.write_empty
        info("writing #{file}")
        AIXM.config.mid = AIPP.options.mid
        File.write(file, aixm.to_xml)
      else
        info("no features to write")
      end
    end

    # Write build information.
    def write_build
      info("skipping build")
    end

    # Write the configuration to config.yml.
    def write_config
      info("writing config.yml")
      AIPP.config.write! config_file
    end

    def class_for(section)
      [:AIPP, AIPP.options.region, AIPP.options.scope, section.classify].constantize
    end
  end

end
