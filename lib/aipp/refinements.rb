module AIPP
  module Refinements

    # @!method blank_to_nil
    #   Convert blank strings to +nil+.
    #
    #   @example
    #     "foobar".blank_to_nil   # => "foobar"
    #     " ".blank_to_nil        # => nil
    #     "".blank_to_nil         # => nil
    #     nil.blank_to_nil        # => nil
    #
    #   @note This is a refinement for +String+ and +NilClass+
    #   @return [String, nil] converted string
    refine String do
      def blank_to_nil
        match?(/\A\s*\z/) ? nil : self
      end
    end

    # Always returns +nil+, companion to +String#blank_to_nil+.
    refine NilClass do
      def blank_to_nil
        nil
      end
    end

    # @!method blank?
    #   Check whether the string is blank.
    #
    #   @example
    #     "foobar".blank?   # => false
    #     " ".blank?        # => true
    #     "".blank?         # => true
    #     nil.blank?        # => true
    #
    #   @note This is a refinement for +String+ and +NilClass+
    #   @return [Boolean] whether the string is blank or not
    refine String do
      def blank?
        !blank_to_nil
      end
    end

    # Always returns +true+, companion to +String#blank?+.
    refine NilClass do
      def blank?
        true
      end
    end

    # @!method classify
    #   Convert file name to class name.
    #
    #   @example
    #     "ENR-5.1".classify   # => "ENR51"
    #     "helper".classify    # => "Helper"
    #     "foo_bar".classify   # => "FooBar"
    #
    #   @note This is a refinement for +String+
    #   @return [String] converted string
    refine String do
      def classify
        gsub(/\W/, '').gsub(/(?:^|_)(\w)/) { $1.upcase }
      end
    end

    # @!method constantize
    #   Get constant for array containing the lookup path.
    #
    #   @example
    #     %w(AIPP AIRAC).constantize   # => AIPP::AIRAC
    #
    #   @note This is a refinement for +Array+
    #   @return [Class] converted array
    refine Array do
      def constantize
        Kernel.const_get(self.join('::'))
      end
    end

    # @!method split(object=nil, &block)
    #   Divides an enumerable into sub-enumerables based on a delimiter,
    #   returning an array of these sub-enumerables.
    #
    #   It takes the same arguments as +Enumerable#find_index+ and suppresses
    #   trailing zero-length sub-enumerator as does +String#split+.
    #
    #   @example
    #     [1, 2, 0, 3, 4].split { |e| e == 0 }   # => [[1, 2], [3, 4]]
    #     [1, 2, 0, 3, 4].split(0)               # => [[1, 2], [3, 4]]
    #     [0, 0, 1, 0, 2].split(0)               # => [[], [] [1], [2]]
    #     [1, 0, 0, 2, 3].split(0)               # => [[1], [], [2], [3]]
    #     [1, 0, 2, 0, 0].split(0)               # => [[1], [2]]
    #
    #   @note This is a refinement for +Enumerable+
    #   @param object [Object] element at which to split
    #   @yield [Object] element to analyze
    #   @yieldreturn [Boolean] whether to split at this element or not
    #   @return [Array]
    refine Enumerable do
      def split(*args, &block)
        [].tap do |array|
          while index = slice((start ||= 0)...length).find_index(*args, &block)
            array << slice(start...start+index)
            start += index + 1
          end
          array << slice(start..-1) if start < length
        end
      end
    end

  end
end
