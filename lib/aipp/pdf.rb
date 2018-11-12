module AIPP

  # PDF to text reader with support for pages and fencing
  #
  # @example
  #   pdf = AIPP::PDF.new("/path/to/file.pdf")
  #   pdf.from(100).to(200).each_line_with_page do |line, page|
  #     line   # => "first line" etc
  #     page   # => 1 etc
  #   end
  class PDF

    def initialize(file)
      @file = file
      @pages = ::PDF::Reader.new(@file).pages
      @text = @pages.map(&:text).join("\f")
      @from = 0
      @to = @last = @text.length - 1
    end

    # Fence the PDF beginning with this position
    #
    # @param position [Integer, Symbol] either an integer position within the
    #   +text+ string or +:begin+ to indicate "first existing position"
    # @return [self]
    def from(position)
      position = 0 if position == :begin
      fail ArgumentError unless (0..@to).include? position
      @from = position
      self
    end

    # Fence the PDF ending with this position
    #
    # @param position [Integer, Symbol] either an integer position within the
    #   +text+ string or +:end+ to indicate "last existing position"
    # @return [self]
    def to(position)
      position = @last if position == :end
      fail ArgumentError unless (@from..@last).include? position
      @to = position
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

    # Enumerator of each line mapped to the page
    #
    # @return [Enumerator]
    def each_line_with_page
      offset = @from
      text.split(/(?<=[\n\f])/).map do |line|
        [line, page_for(position: offset)].tap { |_| offset += line.length }
      end.to_enum
    end

    private

    def page_ranges
      @page_ranges ||= begin
        [].tap do |page_ranges|
          @pages.each_with_index  do |page, index|
            page_ranges << (page_ranges.last || 0) + page.text.length + index
          end
        end
      end
    end

    def page_for(position:)
      page_ranges.index(page_ranges.bsearch { |p| p >= position }) + 1
    end
  end
end
