module AIPP

  # @abstract
  class AIP
    extend Forwardable

    DEPENDS = []

    # @return [String] AIP name (e.g. "ENR-2.1")
    attr_reader :aip

    # @!method config
    #   @return (see AIPP::Parser#config)
    # @!method options
    #   @return (see AIPP::Parser#options)
    # @!method cache
    #   @return (see AIPP::Parser#cache)
    def_delegators :@parser, :aixm, :config, :options, :cache
    private :aixm

    # @!method close
    #   @return (see AIPP::Downloader#close)
    def_delegators :@downloader, :close

    def initialize(aip:, downloader:, parser:)
      @aip, @downloader, @parser = aip, downloader, parser
      self.class.include ("AIPP::%s::Helper" % options[:region]).constantize
    end

    # Read an AIP source file
    #
    # Depending on whether a local copy of the file exists, either:
    # * download from URL to local storage and read from local archive
    # * read from local archive
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

    # Write feature to AIXM
    #
    # @param feature [AIXM::Feature] e.g. airport or airspace
    def write(feature)
      aixm.features << feature
    end
  end

end
