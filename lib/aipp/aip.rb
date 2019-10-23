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
    # @param aip_file [String] e.g. "ENR-2.1" or "AD-2.LFMV" (default: +aip+)
    # @return [Nokogiri::HTML5::Document, String] HTML as Nokogiri document,
    #   PDF or TXT as String
    def read(aip_file=nil)
      aip_file ||= aip
      @downloader.read(document: aip_file, url: url_for(aip_file))
    end

    # Add feature to AIXM
    #
    # @param feature [AIXM::Feature] e.g. airport or airspace
    def add(feature)
      verbose_info "Adding #{feature.inspect}"
      aixm.features << feature
    end

    # Search features previously written to AIXM and return those matching the
    # given class and attribute values
    #
    # @example
    #   select(:airport, id: "LFNT")
    #
    # @param klass [Class, Symbol] feature class like AIXM::Feature::Airport or
    #   AIXM::Feature::NavigationalAid::VOR, shorthand notations as symbols
    #   e.g. :airport or :vor as listed in AIXM::CLASSES are recognized as well
    # @param attributes [Hash] filter by these attributes and their values
    # @return [Array<AIXM::Feature>]
    def select(*args)
      aixm.select_features(*args)
    end
  end

end
