module AIPP
  module Refinements

    # @!method blank_to_nil
    #   Convert blank strings to +nil+.
    #
    #   @example
    #     "foobar".blank_to_nil   # => "foobar"
    #     " ".blank_to_nil        # => nil
    #     "".blank_to_nil         # => nil
    #
    #   @note This is a refinement for +String+
    #   @return [String, nil] converted string
    refine String do
      def blank_to_nil
        match?(/\A\s*\z/) ? nil : self
      end
    end

    # Always returns +nil+, companion to +String#blank_to_nil+.
    refine NilClass do
      def blank_to_nil
        self
      end
    end

    # @!method constantize
    #   Get constant for string after doing some minimalistic cleanup.
    #
    #   @example
    #     "AIPP::AIRAC".constantize   # => AIPP::AIRAC
    #
    #   @note This is a refinement for +String+
    #   @return [Class] converted string
    refine String do
      def constantize
        Kernel.const_get(gsub(/[^\w:]/, ''))
      end
    end

    # @!method split
    #   Split an array into nested arrays at the pattern (similar to
    #   +String#split+).
    #
    #   @example
    #     [1, 2, '---', 3, 4].split(/-+/)   # => [[1, 2], [3, 4]]
    #
    #   @note This is a refinement for +Array+
    #   @param pattern [Regexp] key or value of the hash
    #   @return [Array]
    refine Array do
      def split(pattern)
        [].tap do |array|
          nested_array = []
          each do |element|
            if pattern === element
              array << nested_array
              nested_array = []
            else
              nested_array << element
            end
          end
          array << nested_array
          array.pop while array.last == []
        end
      end
    end

  end
end
