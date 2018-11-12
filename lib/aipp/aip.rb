module AIPP

  # @abstract
  class AIP
    using AIPP::Refinements
    include AIPP::Progress
    extend Forwardable

    DEPENDS = []

    # @return [String] AIP name (e.g. "ENR-2.1")
    attr_reader :aip

    # @return [AIXM::Document] target document
    attr_reader :aixm

    # @!method aixm
    #   @return (see AIPP::Parser#aixm)
    # @!method config
    #   @return (see AIPP::Parser#config)
    # @!method options
    #   @return (see AIPP::Parser#options)
    # @!method cache
    #   @return (see AIPP::Parser#cache)
    def_delegators :@parser, :aixm, :config, :options, :cache

    def initialize(aip:, parser:)
      @aip, @parser = aip, parser
      self.class.include [:AIPP, options[:region], :Helper].constantize
    end

    # Load an AIP source file
    #
    # Depending on whether a local copy of the file exists, either:
    # * download from URL to local storage and read from local storage
    # * read from local storage
    #
    # An URL builder method +url_for(aip_file)+ must be defined either in
    # +helper.rb+ or in the AIP parser definition (e.g. +ENR-2.1.rb+).
    #
    # @param aip_file [String] e.g. "ENR-2.1" or "AD-2.LFMV" (default: +aip+)
    # @return [Nokogiri::HTML5] HTML document
    def load_html(aip_file: nil)
      aip_file ||= aip
      unless (aip_path = storage_path(aip_file)).exist?
        info("Downloading #{aip_file}", force: true)
        storage_path.mkpath
        IO.copy_stream(open(url_for(aip_file)), aip_path)
      end
      Nokogiri::HTML5(aip_path)
    end

    private

    def storage_path(aip_file=nil)
      options[:storage].
        join(options[:airac].date.xmlschema).
        join(("#{aip_file}.html" if aip_file).to_s)
    end

  end

end
