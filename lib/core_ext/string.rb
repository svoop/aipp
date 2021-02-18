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
  def compact
    split("\n").map { _1.squish.blank_to_nil }.compact.join("\n")
  end

  # Calculate the correlation of two strings by counting mutual words
  #
  # Both strings are normalized as follows:
  # * remove accents, umlauts etc
  # * remove everything but members of the +\w+ class
  # * downcase
  #
  # The normalized strings are split into words. Only words fulfilling either
  # of the following conditions are taken into consideration:
  # * words present in and translated by the +synonyms+ map
  # * words of at least 5 characters length
  # * words consisting of exactly one letter followed by any number of digits
  #   (an optional whitespace between the two is ignored, e.g. "D 25" is the
  #   same as "D25")
  #
  # The +synonyms+ map is an array where terms in even positions map to their
  # synonym in the following (odd) position:
  #
  #   SYNONYMS = ['term1', 'synonym1', 'term2', 'synonym2']
  #
  # @example
  #   subject = "Truck en route on N 3 sud"
  #   subject.correlate("my car is on D25")          # => 0
  #   subject.correlate("my truck is on D25")        # => 1
  #   subject.correlate("my truck is on N3")         # => 2
  #   subject.correlate("south", ['sud', 'south'])   # => 1
  #
  # @param other [String] string to compare with
  # @param synonyms [Array<String>] array of synonym pairs
  # @return [Integer] 0 for unrelated strings and positive integers for related
  #   strings with higher numbers indicating tighter correlation
  def correlate(other, synonyms=[])
    self_words, other_words = [self, other].map do |string|
      string.
        unicode_normalize(:nfd).
        downcase.gsub(/[-\u2013]/, ' ').
        remove(/[^\w\s]/).
        gsub(/\b(\w)\s?(\d+)\b/, '\1\2').
        compact.
        split(/\W+/).
        map { (i = synonyms.index(_1)).nil? ? _1 : (i.odd? ? _1 : synonyms[i + 1]).upcase }.
        keep_if { _1.match?(/\w{5,}|\w\d+|[[:upper:]]/) }.
        uniq
    end
    (self_words & other_words).count
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

  # Apply the pattern and return...
  # * first capture group - if the pattern matches and contains a capture group
  # * entire match - if the pattern matches and contains no capture group
  # * +default+ - if it doesn't match but has a +default+ set
  # * +nil+ - if it doesn't match and doesn't have a +default+ set
  #
  # @example
  #   "A/A: 123.5 mhz".first_match(/123\.5/)                   # => "123.5"
  #   "A/A: 123.5 mhz".first_match(/:\s+([\d.]+)/)             # => "123.5"
  #   "A/A: 123.5 mhz".first_match(/121\.5/)                   # nil
  #   "A/A: 123.5 mhz".first_match(/(121\.5)/)                 # nil
  #   "A/A: 123.5 mhz".first_match(/121\.5/, default: "123")   # "123"
  #
  # @param pattern [Regexp] pattern to apply
  # @param default [String] string to return instead of +nil+ if the pattern
  #   doesn't match
  # @return [String, nil]
  def first_match(pattern, default: nil)
    if captures = match(pattern)
      captures[1] || captures[0]
    end || default
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

  # Add spaces between obviously glued words:
  # * camel glued words
  # * three-or-more-letter and number-only words
  #
  # @example
  #   "thisString has spaceProblems".unglue   # => "this String has space problems"
  #   "the first123meters of D25".unglue      # => "the first 123 meters of D25"
  #
  # @return [String] unglued string
  def unglue
    self.dup.tap do |string|
      [/([[:lower:]])([[:upper:]])/, /([[:alpha:]]{3,})(\d)/, /(\d)([[:alpha:]]{3,})/].freeze.each do |regexp|
        string.gsub!(regexp, '\1 \2')
      end
    end
  end

end
