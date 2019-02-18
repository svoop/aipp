module AIPP

  # AIP parser infrastructure
  class Parser

    # @return [Hash] passed command line arguments
    attr_reader :options

    # @return [Hash] configuration read from config.yml
    attr_reader :config

    # @return [AIXM::Document] target document
    attr_reader :aixm

    # @return [OpenStruct] object cache
    attr_reader :cache

    def initialize(options:)
      @options = options
      @options[:storage] = options[:storage].join(options[:region])
      @options[:storage].mkpath unless @options[:storage].exist?
      @config = {}
      @aixm = AIXM.document(region: @options[:region], effective_at: @options[:airac].date)
      @dependencies = THash.new
      @cache = OpenStruct.new
    end

    # Read the configuration from config.yml.
    def read_config
      info("Reading config.yml")
      @config = YAML.load_file(config_file, fallback: {}).transform_keys(&:to_sym) if config_file.exist?
      @config[:namespace] ||= SecureRandom.uuid
      @aixm.namespace = @config[:namespace]
    end

    # Read the region directory and build the dependency list.
    def read_region
      info("Reading region #{options[:region]}")
      dir = Pathname(__FILE__).dirname.join('regions', options[:region])
      fail("unknown region `#{options[:region]}'") unless dir.exist?
      dir.glob('*.rb').each do |file|
        debug("Requiring #{file.basename}")
        require file
        if (aip = file.basename('.*').to_s) == 'helper'
          extend ("AIPP::%s::Helper" % options[:region]).constantize
        else
          @dependencies[aip] = ("AIPP::%s::%s::DEPENDS" % [options[:region], aip.remove(/\W/).classify]).constantize
        end
      end
    end

    # Parse AIP by invoking the parser classes for the current region.
    def parse_aip
      info("AIRAC #{options[:airac].id} effective #{options[:airac].date}", color: :green)
      AIPP::Downloader.new(storage: options[:storage], archive: options[:airac].date.xmlschema) do |downloader|
        @dependencies.tsort(options[:aip]).each do |aip|
          info("Parsing #{aip}")
          parser = ("AIPP::%s::%s" % [options[:region], aip.remove(/\W/).classify]).constantize.new(
            aip: aip,
            downloader: downloader,
            parser: self
          )
          parser.parse
          parser.class.remove_patches
        end
      end
    end

    # Validate the AIXM document.
    #
    # @raise [RuntimeError] if the document is not valid
    def validate_aixm
      info("Validating #{options[:schema].upcase}")
      unless aixm.valid?
        message = "invalid AIXM document:\n" + aixm.errors.map(&:message).join("\n")
        @options[:force] ? warn(message, pry: binding) : fail(message)
      end
    end

    # Write the AIXM document.
    def write_aixm
      file = "#{options[:region]}_#{options[:airac].date.xmlschema}.#{options[:schema]}"
      info("Writing #{file}")
      AIXM.send("#{options[:schema]}!")
      File.write(file, aixm.to_xml)
    end

    # Write the configuration to config.yml.
    def write_config
      info("Writing config.yml")
      File.write(config_file, config.to_yaml)
    end

    private

    def config_file
      options[:storage].join('config.yml')
    end
  end

end
