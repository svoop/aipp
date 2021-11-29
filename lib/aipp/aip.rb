module AIPP

  # @abstract
  class AIP
    extend Forwardable
    include AIPP::Debugger
    include AIPP::Patcher

    DEPENDS = []

    # @return [String] AIP name (equal to the parser file name without its
    #   file extension such as "ENR-2.1" implemented in the file "ENR-2.1.rb")
    attr_reader :aip

    # @return [String] AIP file as passed and possibly updated by `url_for`
    attr_reader :aip_file

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
      setup if respond_to? :setup
    end

    # @return [String]
    def inspect
      "#<AIPP::AIP #{aip}>"
    end

    # Read an AIP source file
    #
    # Read the cached source file if it exists in the source archive. Otherwise,
    # download it from URL and cache it.
    #
    # An URL builder method +url_for(aip_file)+ must be implemented by the AIP
    # parser definition (e.g. +ENR-2.1.rb+).
    #
    # @param aip_file [String] e.g. "ENR-2.1" or "AD-2.LFMV" (default: +aip+
    #   with section stripped e.g. "AD-1.3-2" -> "AD-1.3")
    # @return [Nokogiri::XML::Document, Nokogiri::HTML5::Document,
    #   Roo::Spreadsheet, String] XML/HTML as Nokogiri document, XLSX/ODS/CSV
    #   as Roo document, PDF and TXT as String
    def read(aip_file=nil)
      @aip_file = aip_file || aip.remove(/(?<![A-Z])-\d+$/)
      url = url_for(@aip_file)   # may update aip_file string
      @downloader.read(document: @aip_file, url: url)
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
    #   options[:check_links] = false
    #   link_to('foo', 'https://bar.com/exists')      # => "[foo](https://bar.com/exists)"
    #   link_to('foo', 'https://bar.com/not-found')   # => "[foo](https://bar.com/not-found)"
    #   options[:check_links] = true
    #   link_to('foo', 'https://bar.com/exists')      # => "[foo](https://bar.com/exists)"
    #   link_to('foo', 'https://bar.com/not-found')   # => nil
    #
    # @params body [String] body text of the link
    # @params url [String] URL of the link
    # @return [String, nil] Markdown link
    def link_to(body, url)
      "[#{body}](#{url})" if !options[:check_links] || url_exists?(url)
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
