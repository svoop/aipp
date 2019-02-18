module AIPP

  # PDF to text reader with support for pages and fencing
  #
  # @example
  #   pdf = AIPP::PDF.new("/path/to/file.pdf")
  #   pdf.file   # => #<Pathname:/path/to/file.pdf>
  #   pdf.from(100).to(200).each_line_with_position do |line, page, last|
  #     line   # => line content (e.g. "first line")
  #     page   # => page number (e.g. 1)
  #     last   # => last line boolean (true for last line, false otherwise)
  #   end
  class PDF
    attr_reader :file

    def initialize(file, cache: true)
      @file = file.is_a?(Pathname) ? file : Pathname(file)
      @text, @page_ranges = cache ? read_cache : read
      @from = 0
      @to = @last = @text.length - 1
    end

    # @return [String]
    def inspect
      %Q(#<#{self.class} file=#{@file} range=#{range}>)
    end

    # Fence the PDF beginning with this index
    #
    # @param index [Integer, Symbol] either an integer position within the
    #   +text+ string or +:begin+ to indicate "first existing position"
    # @return [self]
    def from(index)
      index = 0 if index == :begin
      fail ArgumentError unless (0..@to).include? index
      @from = index
      self
    end

    # Fence the PDF ending with this index
    #
    # @param index [Integer, Symbol] either an integer position within the
    #   +text+ string or +:end+ to indicate "last existing position"
    # @return [self]
    def to(index)
      index = @last if index == :end
      fail ArgumentError unless (@from..@last).include? index
      @to = index
      self
    end

    # Get the current fencing range
    #
    # @return [Range<Integer>]
    def range
      (@from..@to)
    end

    # Text string of the PDF with fencing applied
    #
    # @return [String] PDF converted to string
    def text
      @text[range]
    end

    # Text split to individual lines
    #
    # @return [Array] lines
    def lines
      text.split(/(?<=[\n\f])/)
    end

    # Executes the block for every line and passes the line content, page
    # number and end of document boolean.
    #
    # If no block is given, an enumerator is returned instead.
    #
    # @yieldparam line [String] content of the line
    # @yieldparam page [Integer] page number the line is found on within the PDF
    # @yieldparam last [Boolean] true for the last line, false otherwise
    # @return [Enumerator]
    def each_line
      return enum_for(:each) unless block_given?
      offset, last_line_index = @from, lines.count - 1
      lines.each_with_index do |line, line_index|
        yield(line, page_for(index: offset), line_index == last_line_index)
        offset += line.length
      end
    end
    alias_method :each, :each_line

    private

    def read
      pages = ::PDF::Reader.new(@file).pages
      [pages.map(&:text).join("\f"), page_ranges_for(pages)]
    end

    def read_cache
      cache_file = "#{@file}.json"
      if File.exist?(cache_file) && (File.stat(@file).mtime - File.stat(cache_file).mtime).abs < 1
        JSON.load File.read(cache_file)
      else
        read.tap do |data|
          File.write(cache_file, data.to_json)
          FileUtils.touch(cache_file, mtime: File.stat(@file).mtime)
        end
      end
    end

    def page_ranges_for(pages)
      [].tap do |page_ranges|
        pages.each_with_index  do |page, index|
          page_ranges << (page_ranges.last || 0) + page.text.length + index
        end
      end
    end

    def page_for(index:)
      @page_ranges.index(@page_ranges.bsearch { |i| i >= index }) + 1
    end
  end
end
