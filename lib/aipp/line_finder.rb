module AIPP

  # This is a workaround for Nokogiri/Nokogumbo not reporting the line of first
  # occurrence in HTML files!
  class LineFinder

    def initialize(html_file:)
      @text = IO.read(html_file).
        gsub(/(<.*?>|&.*?;)/, '').   # remove tags and entities
        gsub(/[^\w\n]/, '')          # remove all but alnums and newlines
    end

    # Line number in HTML file on which the node begins. The node has to contain
    # unique CDATA for this to work.
    #
    # @return [Integer] line number
    def line(node:)
      pattern = node.text.
        gsub(/[^\w\n]/, '').   # remove all but alnums and newlines
        strip.
        gsub(/\n+/, "\n*")     # collapse newlines
      position = @text =~ /#{pattern}/
      @text[0..position].count("\n") + 1
    end

  end
end
