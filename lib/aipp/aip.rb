module AIPP

  # @abstract
  class AIP
    extend Forwardable
    include AIPP::Patcher

    DEPENDS = []

    # @return [String] AIP name (e.g. "ENR-2.1")
    attr_reader :aip

    # @return [Object] Fixture read from YAML file
    attr_reader :fixture

    # @!method close
    #   @see AIPP::Downloader#close
    def_delegator :@downloader, :close

    # @!method config
    #   @see AIPP::Parser#config
    # @!method options
    #   @see AIPP::Parser#options
    # @!method borders
    #   @see AIPP::Parser#borders
    # @!method cache
    #   @see AIPP::Parser#cache
    def_delegators :@parser, :aixm, :config, :options, :borders, :cache
    private :aixm

    def initialize(aip:, downloader:, fixture:, parser:)
      @aip, @downloader, @fixture, @parser = aip, downloader, fixture, parser
      self.class.include ("AIPP::%s::Helpers::URL" % options[:region]).constantize
    end

    # Read an AIP source file
    #
    # Read the cached source file if it exists in the source archive. Otherwise,
    # download it from URL and cache it.
    #
    # An URL builder method +url_for(aip_file)+ must be defined either in
    # +helper.rb+ or in the AIP parser definition (e.g. +ENR-2.1.rb+).
    #
    # @param aip_file [String] e.g. "ENR-2.1" or "AD-2.LFMV" (default: +aip+
    #   with section stripped e.g. "AD-1.3-2" -> "AD-1.3")
    # @return [Nokogiri::HTML5::Document, String] HTML as Nokogiri document,
    #   PDF or TXT as String
    def read(aip_file=nil)
      aip_file ||= aip.remove(/(?<![A-Z])-\d+$/)
      @downloader.read(document: aip_file, url: url_for(aip_file))
    end

    # Add feature to AIXM
    #
    # @param feature [AIXM::Feature] e.g. airport or airspace
    # @return [AIXM::Feature] added feature
    def add(feature)
      verbose_info "Adding #{feature.inspect}"
      aixm.add_feature feature
      feature
    end

    # @!method find_by(klass, attributes={})
    #   Find objects of the given class and optionally with the given attribute
    #   values previously written to AIXM.
    #
    #   @note This method is delegated to +AIXM::Association::Array+.
    #   @see https://www.rubydoc.info/gems/aixm/AIXM/Association/Array#find_by-instance_method
    #
    # @!method find(object)
    #   Find equal objects previously written to AIXM.
    #
    #   @note This method is delegated to +AIXM::Association::Array+.
    #   @see https://www.rubydoc.info/gems/aixm/AIXM/Association/Array#find-instance_method
    %i(find_by find).each do |method|
      define_method method do |*args|
        aixm.features.send(method, *args)
      end
    end
  end

end
