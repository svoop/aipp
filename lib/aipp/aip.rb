module AIPP

  # @abstract
  class AIP
    using AIPP::Refinements
    include AIPP::Progress

    DEPENDS = []

    # @return [Nokogiri::HTML::Document] source HTML document
    attr_reader :html

    # @return [AIXM::Document] target document
    attr_reader :aixm

    # @return [Hash] configuration read from config.yml
    attr_reader :config

    # @return [Hash] passed command line arguments
    attr_reader :options

    def initialize(html:, aixm:, config:, options:)
      @html, @aixm, @config, @options = html, aixm, config, options
      self.class.include [:AIPP, options[:region], :Helper].constantize
    end

  end

end
