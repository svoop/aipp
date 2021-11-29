class String

  # Convert blank strings to +nil+.
  #
  # @example
  #   "foobar".blank_to_nil   # => "foobar"
  #   " ".blank_to_nil        # => nil
  #   "".blank_to_nil         # => nil
  #   nil.blank_to_nil        # => nil
  #
  # @return [String, nil] converted string
  def blank_to_nil
    self if present?
  end

  # Fix messy oddities such as the use of two apostrophes instead of a quote
  #
  # @example
  #   "the ''Terror'' was a fine ship".cleanup   # => "the \"Terror\" was a fine ship"
  #
  # @return [String] cleaned string
  def cleanup
    gsub(/[#{AIXM::MIN}]{2}|[#{AIXM::SEC}]/, '"').   # unify quotes
      gsub(/[#{AIXM::MIN}]/, "'").   # unify apostrophes
      gsub(/"[[:blank:]]*(.*?)[[:blank:]]*"/m, '"\1"').   # remove whitespace within quotes
      split(/\r?\n/).map { _1.strip.blank_to_nil }.compact.join("\n")   # remove blank lines
  end

  # Strip and collapse unnecessary whitespace
  #
  # @note While similar to +String#squish+ from ActiveSupport, newlines +\n+
  #   are preserved and not collapsed into one space.
  #
  # @example
  #   "  foo\n\nbar \r".copact   # => "foo\nbar"
  #
  # @return [String] compacted string
  def compact   # TODO: in use, don't remove!
    split("\n").map { _1.squish.blank_to_nil }.compact.join("\n")
  end

  # Similar to +strip+, but remove any leading or trailing non-letters/numbers
  # which includes whitespace
  def full_strip
    remove(/\A[^\p{L}\p{N}]*|[^\p{L}\p{N}]*\z/)
  end

  # Similar to +scan+, but remove matches from the string
  def extract(pattern)
    scan(pattern).tap { remove! pattern }
  end

  # Apply the patterns in the given order and return...
  # * first capture group - if a pattern matches and contains a capture group
  # * entire match - if a pattern matches and contains no capture group
  # * +default+ - if no pattern matches and a +default+ is set
  # * +nil+ - if no pattern matches and no +default+ is set
  #
  # @example
  #   "A/A: 123.5 mhz".first_match(/123\.5/)                   # => "123.5"
  #   "A/A: 123.5 mhz".first_match(/:\s+([\d.]+)/)             # => "123.5"
  #   "A/A: 123.5 mhz".first_match(/121\.5/)                   # nil
  #   "A/A: 123.5 mhz".first_match(/(121\.5)/)                 # nil
  #   "A/A: 123.5 mhz".first_match(/121\.5/, default: "123")   # "123"
  #
  # @param patterns [Array<Regexp>] one or more patterns to apply in order
  # @param default [String] string to return instead of +nil+ if the pattern
  #   doesn't match
  # @return [String, nil]
  def first_match(*patterns, default: nil)
    patterns.each do |pattern|
      if captures = match(pattern)
        return captures[1] || captures[0]
      end
    end
    default
  end

  # Remove all XML/HTML tags and entities from the string
  def strip_markup
    self.gsub(/<.*?>|&[#\da-z]+;/i, '')
  end

  # Same as +to_f+ but accept both dot and comma as decimal separator
  #
  # @example
  #   "5.5".to_ff    # => 5.5
  #   "5,6".to_ff    # => 5.6
  #   "5,6".to_f     # => 5.0   (sic!)
  #
  # @return [Float] number parsed from text
  def to_ff
    sub(/,/, '.').to_f
  end

end
