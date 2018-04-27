module AIPP

  # @abstract
  class AIP
    using AIPP::Refinements

    # @return [Nokogiri::HTML::Document] source HTML document
    attr_reader :html

    # @return [AIXM::Document] target document
    attr_reader :aixm

    # @return [Hash] configuration read from config.yml
    attr_reader :config

    # @return [Hash] passed command line arguments
    attr_reader :options

    def initialize(html:, aixm:, config:, options:, line_finder:)
      @html, @aixm, @config, @options, @line_finder = html, aixm, config, options, line_finder
      self.class.include ['AIPP', options[:region], 'Helper'].join('::').constantize
    end

    # Issue a warning and maybe open a Pry session.
    #
    # @example
    #   warn("oops", binding)
    def warn(message, binding=nil)
      Kernel.warn "WARNING: #{message}"
      binding.pry if options[:pry_on_warn] && binding && binding.respond_to?(:pry)
    end

    # Find line of first occurrence of node in HTML source.
    #
    # @see AIPP::LineFinder
    def line(node:)
      @line_finder.line(node: node)
    end
  end

end
