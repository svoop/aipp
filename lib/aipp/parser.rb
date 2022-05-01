module AIPP

  # @abstract
  class Parser
    include AIPP::Debugger
    include AIPP::Patcher

    # @return [AIXM::Document] AIXM document instance
    attr_reader :aixm

    class << self
      # Declare a dependency
      #
      # @param dependencies [Array<String>] class names of other parsers this
      #   parser depends on
      def depends_on(*dependencies)
        @dependencies = dependencies.map(&:to_s)
      end

      # Declared dependencies
      #
      # @return [Array<String>] class names of other parsers this parser
      #   depends on
      def dependencies
        @dependencies || []
      end
    end

    def initialize(downloader:, aixm:)
      @downloader, @aixm = downloader, aixm
      setup if respond_to? :setup
    end

    # @return [String]
    def inspect
      "#<AIPP::Parser #{section}>"
    end

    # @return [String]
    def section
      self.class.to_s.sectionize
    end

    # @abstract
    def url_for(*)
      fail "url_for method must be implemented in parser"
    end

    # Read a source document
    #
    # Read the cached document if it exists in the source archive. Otherwise,
    # download and cache it.
    #
    # An URL builder method +url_for+ must be implemented by the parser
    # definition.
    #
    # The file type is derived from the URL (e.g. `https://foo.bar/doc.pdf`
    # is a PDF file), however, if the URL does not expose the file type
    # or a wrong file type, you can force it with a prefix (e.g.
    # `pdf+https://example.com/doc` is a PDF file as well).
    #
    # @param document [String] e.g. "ENR-2.1" or "aerodromes" (default: current
    #   +section+)
    # @return [Nokogiri::XML::Document, Nokogiri::HTML5::Document,
    #   Roo::Spreadsheet, String] document
    def read(document=section)
      @downloader.read(
        document: document,
        url: url_for(document).sub(/\A(\w+)\+/ , ''),
        type: $1&.to_sym
      )
    end

    # Add feature to AIXM
    #
    # @param feature [AIXM::Feature] e.g. airport or airspace
    # @return [AIXM::Feature] added feature
    def add(feature)
      verbose_info "adding #{feature.inspect}"
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

    # @overload given(*objects)
    #   Return +objects+ unless at least one of them equals nil
    #
    #   @example
    #     # Instead of this:
    #     first, last = unless ((first = expensive_first).nil? || (last = expensive_last).nil?)
    #       [first, last]
    #     end
    #
    #     # Use the following:
    #     first, last = given(expensive_first, expensive_last)
    #
    #   @param *objects [Array<Object>] any objects really
    #   @return [Object] nil if at least one of the objects is nil, given
    #     objects otherwise
    #
    # @overload given(*objects)
    #   Yield +objects+ unless at least one of them equals nil
    #
    #   @example
    #     # Instead of this:
    #     name = unless ((first = expensive_first.nil? || (last = expensive_last.nil?)
    #       "#{first} #{last}"
    #     end
    #
    #     # Use any of the following:
    #     name = given(expensive_first, expensive_last) { |f, l| "#{f} #{l}" }
    #     name = given(expensive_first, expensive_last) { "#{_1} #{_2}" }
    #
    #   @param *objects [Array<Object>] any objects really
    #   @yield [Array<Object>] objects passed as parameter
    #   @return [Object] nil if at least one of the objects is nil, return of
    #     block otherwise
    def given(*objects)
      if objects.none?(&:nil?)
        block_given? ? yield(*objects) : objects
      end
    end

    # Build and optionally check a Markdown link
    #
    # @example
    #   AIPP.options.check_links = false
    #   link_to('foo', 'https://bar.com/exists')      # => "[foo](https://bar.com/exists)"
    #   link_to('foo', 'https://bar.com/not-found')   # => "[foo](https://bar.com/not-found)"
    #   AIPP.options.check_links = true
    #   link_to('foo', 'https://bar.com/exists')      # => "[foo](https://bar.com/exists)"
    #   link_to('foo', 'https://bar.com/not-found')   # => nil
    #
    # @param body [String] body text of the link
    # @param url [String] URL of the link
    # @return [String, nil] Markdown link
    def link_to(body, url)
      "[#{body}](#{url})" if !AIPP.options.check_links || url_exists?(url)
    end

    private

    def url_exists?(url)
      uri = URI.parse(url)
      Net::HTTP.new(uri.host, uri.port).tap do |request|
        request.use_ssl = (uri.scheme == 'https')
        path = uri.path.present? ? uri.path : '/'
        result = request.request_head(path)
        if result.kind_of? Net::HTTPRedirection
          url_exist?(result['location'])
        else
          result.code == '200'
        end
      end
    end

  end
end
