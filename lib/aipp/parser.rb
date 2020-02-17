module AIPP

  # AIP parser infrastructure
  class Parser

    using AIXM::Refinements

    # @return [Hash] passed command line arguments
    attr_reader :options

    # @return [Hash] configuration read from config.yml
    attr_reader :config

    # @return [AIXM::Document] target document
    attr_reader :aixm

    # @return [Hash] map from AIP name to fixtures
    attr_reader :fixtures

    # @return [Hash] map from border names to border objects
    attr_reader :borders

    # @return [OpenStruct] object cache
    attr_reader :cache

    def initialize(options:)
      @options = options
      @options[:storage] = options[:storage].join(options[:region])
      @options[:storage].mkpath
      @config = {}
      @aixm = AIXM.document(effective_at: @options[:airac].date)
      @dependencies = THash.new
      @fixtures = {}
      @borders = {}
      @cache = OpenStruct.new
      AIXM.send("#{options[:schema]}!")
      AIXM.config.region = options[:region]
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
      # Fixtures
      dir.glob('fixtures/*.yml').each do |file|
        verbose_info "Reading fixture fixtures/#{file.basename}"
        fixture = YAML.load_file(file)
        @fixtures[file.basename('.yml').to_s] = fixture
      end
      # Borders
      dir.glob('borders/*.geojson').each do |file|
        verbose_info "Reading border borders/#{file.basename}"
        border = AIPP::Border.new(file)
        @borders[border.name] = border
      end
      # Helpers
      dir.glob('helpers/*.rb').each do |file|
        verbose_info "Reading helper helpers/#{file.basename}"
        require file
      end
      # Parsers
      dir.glob('*.rb').each do |file|
        verbose_info "Requiring #{file.basename}"
        require file
        aip = file.basename('.*').to_s
        @dependencies[aip] = ("AIPP::%s::%s::DEPENDS" % [options[:region], aip.remove(/\W/).classify]).constantize
      end
    end

    # Parse AIP by invoking the parser classes for the current region.
    def parse_aip
      info("AIRAC #{options[:airac].id} effective #{options[:airac].date}", color: :green)
      AIPP::Downloader.new(storage: options[:storage], source: options[:airac].date.xmlschema) do |downloader|
        @dependencies.tsort(options[:aip]).each do |aip|
          info("Parsing #{aip}")
          ("AIPP::%s::%s" % [options[:region], aip.remove(/\W/).classify]).constantize.new(
            aip: aip,
            downloader: downloader,
            fixture: @fixtures[aip],
            parser: self
          ).attach_patches.tap(&:parse).detach_patches
        end
      end
    end

    # Validate the AIXM document.
    #
    # @raise [RuntimeError] if the document is not valid
    def validate_aixm
      info("Validating #{options[:schema].upcase}")
      unless aixm.valid?
        message = "invalid #{options[:schema].upcase} document:\n" + aixm.errors.map(&:message).join("\n")
        @options[:force] ? warn(message, pry: binding) : fail(message)
      end
    end

    # Write the AIXM document and context information.
    def write_build
      info("Writing build")
      builds_path.mkpath
      build_file = builds_path.join("#{@options[:airac].date.xmlschema}.zip")
      Dir.mktmpdir do |tmp_dir|
        tmp_dir = Pathname(tmp_dir)
        # AIXM/OFMX file
        AIXM.config.mid = true
        File.write(tmp_dir.join(aixm_file), aixm.to_xml)
        # Build details
        File.write(
          tmp_dir.join('build.yaml'), {
            version: AIPP::VERSION,
            config: @config,
            options: @options
          }.to_yaml
        )
        # Manifest
        uids, manifest, buffer, feature, aip, uid, comment = [], [], '', '', '', '', ''
        File.open(tmp_dir.join(aixm_file)).each do |line|
          buffer << line
          case line
          when /^ {2}<(\w{3}).*source=".*?\|.*?\|(.*?)\|/ then buffer, feature, aip = line, $1, $2
          when /^ {4}<#{feature}Uid[^>]+?mid="(.*?)"/ then uid = $1
          when /^ {2}<!-- (.*) -->/ then comment = $1
          when /^ {2}<\/#{feature}>/
            uids << [aip, feature, uid[0,8]].to_csv
            manifest << [aip, feature, uid[0,8], AIXM::PayloadHash.new(buffer).to_uuid[0,8], comment].to_csv
            feature, aip, uid = '', '', ''
          end
        end
        manifest = manifest.sort.prepend "AIP,Feature,Short Uid Hash,Short Feature Hash,Comment\n"
        File.write(tmp_dir.join('manifest.csv'), manifest.join)
        # Detect duplicates
        if dupes = uids.group_by(&:itself).select { |_, v| v.size > 1 }.keys.join
          fail("duplicate UIDs found:\n#{dupes}")
        end
        # Zip it
        build_file.delete if build_file.exist?
        Zip::File.open(build_file, Zip::File::CREATE) do |zip|
          tmp_dir.children.each do |entry|
            zip.add(entry.basename.to_s, entry) unless entry.basename.to_s[0] == '.'
          end
        end
      end
    end

    # Write the AIXM document.
    def write_aixm
      info("Writing #{aixm_file}")
      AIXM.config.mid = options[:mid]
      File.write(aixm_file, aixm.to_xml)
    end

    # Write the configuration to config.yml.
    def write_config
      info("Writing config.yml")
      File.write(config_file, config.to_yaml)
    end

    private

    def aixm_file
      "#{options[:region]}_#{options[:airac].date.xmlschema}.#{options[:schema]}"
    end

    def builds_path
      options[:storage].join('builds')
    end

    def config_file
      options[:storage].join('config.yml')
    end
  end

end
