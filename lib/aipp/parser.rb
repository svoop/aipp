module AIPP

  # AIP parser infrastructure
  class Parser
    using AIPP::Refinements
    include AIPP::Progress

    # @return [AIXM::Document] target document
    attr_reader :aixm

    # @return [Hash] passed command line arguments
    attr_reader :options

    # @return [Hash] configuration read from config.yml
    attr_reader :config

    # @return [OpenStruct] object cache
    attr_reader :cache

    def initialize(options:)
      @options = options
      @config = {}
      @cache = OpenStruct.new
      options[:storage] = options[:storage].join(options[:region])
      options[:storage].mkpath
      @aixm = AIXM.document(region: options[:region], effective_at: options[:airac].date)
    end

    # Read the configuration from config.yml.
    def read_config
      info("Reading config.yml", force: true)
      @config = YAML.load_file(config_file, fallback: {}).transform_keys(&:to_sym) if config_file.exist?
      @config[:namespace] ||= SecureRandom.uuid
      @aixm.namespace = @config[:namespace]
    end

    # Read the region directory and build the dependency list.
    def read_region
      info("Reading region #{options[:region]}", force: true)
      dir = Pathname(__FILE__).dirname.join('regions', options[:region])
      fail("unknown region `#{options[:region]}'") unless dir.exist?
      dependencies = THash.new
      dir.glob('*.rb').each do |file|
        info("Requiring #{file.basename}")
        require file
        if (aip = file.basename('.*').to_s) == 'helper'
          extend [:AIPP, options[:region], :Helper].constantize
        else
          dependencies[aip] = [:AIPP, options[:region], aip.classify, :DEPENDS].constantize
        end
      end
      @aips = dependencies.tsort(options[:aip])
    end

    # Download AIP for the current region and cache them locally.
    def download_html
      info("AIRAC #{options[:airac].id} effective #{options[:airac].date}", force: true, color: :green)
      download_path.mkpath
      @aips.each do |aip|
        unless (file = download_path(aip: aip)).exist?
          info("Downloading #{aip}", force: true)
          IO.copy_stream(open(url(aip: aip)), file)
        end
      end
    end

    # Parse AIP by invoking the parser classes for the current region.
    def parse_html
      @aips.each do |aip|
        info("Parsing #{aip}", force: true)
        [:AIPP, options[:region], aip.classify].constantize.new(
          aixm: aixm,
          html: Nokogiri::HTML5(download_path(aip: aip)),
          config: config,
          options: options
        ).parse
      end
    end

    # Validate the AIXM document.
    #
    # @raise [RuntimeError] if the document is not valid
    def validate_aixm
      info("Validating #{options[:schema].upcase}", force: true)
      unless aixm.valid?
        send(@options[:force] ? :warn : :fail, "invalid AIXM document:\n#{aixm.errors}")
      end 
    end

    # Write the AIXM document.
    def write_aixm
      file = "#{options[:region]}_#{options[:airac].date.xmlschema}.#{options[:schema]}"
      info("Writing #{file}", force: true)
      AIXM.send("#{options[:schema]}!")
      File.write(file, aixm.to_xml)
    end

    # Write the configuration to config.yml.
    def write_config
      info("Writing config.yml", force: true)
      File.write(config_file, config.to_yaml)
    end

    private

    def download_path(aip: nil)
      options[:storage].
        join(options[:airac].date.xmlschema).
        join(("#{aip}.html" if aip).to_s)
    end

    def config_file
      options[:storage].join('config.yml')
    end
  end

end
