module AIPP

  # AIP parser infrastructure
  class Parser
    using AIPP::Refinements

    # @return [AIXM::Document] target document
    attr_reader :aixm

    # @return [Hash] configuration read from config.yml
    attr_reader :config

    # @return [Hash] passed command line arguments
    attr_reader :options

    def initialize(options:)
      @options = options
      options[:storage] = options[:storage].join(options[:region])
      options[:storage].mkpath
      @aixm = AIXM.document
      self.class.include ['AIPP', options[:region], 'Helper'].join('::').constantize
    end

    # Load config.yml.
    def config
      file = options[:storage].join('config.yml')
      @config ||= YAML.load_file(file, fallback: {}).transform_keys(&:to_sym)
    rescue Errno::ENOENT
      {}
    end

    # Download AIP for the current region and cache them locally.
    def download_html
      puts "AIRAC #{options[:airac].id} effective #{options[:airac].date}"
      download_path.mkpath
      aips.each do |aip|
        unless (file = download_path(aip: aip)).exist?
          puts "Downloading #{aip}"
          IO.copy_stream(open(url(aip: aip)), file)
        end
      end
    end

    # Parse AIP by invoking the parser classes for the current region.
    def parse_html
      aips.each do |aip|
        puts "Parsing #{aip}"
        ['AIPP', options[:region], aip].join('::').constantize.new(
          aixm: aixm,
          html: Nokogiri::HTML5(download_path(aip: aip)),
          config: config,
          options: options,
          line_finder: LineFinder.new(html_file: download_path(aip: aip))
        ).parse
      end
    end

    # Validate the AIXM document.
    #
    # @raise [RuntimeError] if the document is not valid
    def validate_aixm
      puts "Validating #{options[:schema].upcase}"
      fail "invalid AIXM document:\n#{aixm.errors}" unless aixm.valid?
    end

    # Write the AIXM document.
    def write_aixm
      file = "#{options[:region]}_#{options[:airac].date.xmlschema}.#{options[:schema]}"
      puts "Writing #{file}"
      AIXM.send("#{options[:schema]}!")
      File.write(file, aixm.to_xml)
    end

    private

    def aips
      if options[:aip]
        fail("unknown AIP") unless AIPS.include?(options[:aip])
        [options[:aip]]
      else
        AIPS
      end
    end

    def download_path(aip: nil)
      options[:storage].
        join(options[:airac].date.xmlschema).
        join(("#{aip}.html" if aip).to_s)
    end
  end

end
