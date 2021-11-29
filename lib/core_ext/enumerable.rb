module Enumerable

  # !method split(object=nil, &block)
  #   Divides an enumerable into sub-enumerables based on a delimiter,
  #   returning an array of these sub-enumerables.
  #
  #   @example
  #     [1, 2, 0, 3, 4].split { _1 == 0 }   # => [[1, 2], [3, 4]]
  #     [1, 2, 0, 3, 4].split(0)            # => [[1, 2], [3, 4]]
  #     [0, 0, 1, 0, 2].split(0)            # => [[], [] [1], [2]]
  #     [1, 0, 0, 2, 3].split(0)            # => [[1], [], [2], [3]]
  #     [1, 0, 2, 0, 0].split(0)            # => [[1], [2]]
  #
  #   @note While similar to +Array#split+ from ActiveSupport, this core
  #     extension works for all enumerables and therefore works fine with.
  #     Nokogiri. Also, it behaves more like +String#split+ by ignoring any
  #     trailing zero-length sub-enumerators.
  #
  #   @param object [Object] element at which to split
  #   @yield [Object] element to analyze
  #   @yieldreturn [Boolean] whether to split at this element or not
  #   @return [Array]
  def split(*args, &)
    [].tap do |array|
      while index = slice((start ||= 0)...length).find_index(*args, &)
        array << slice(start...start+index)
        start += index + 1
      end
      array << slice(start..-1) if start < length
    end
  end

  # !method group_by_chunks(&block)
  #   Build a hash which maps elements matching the chunk condition to
  #   an array of subsequent elements which don't match the chunk condition.
  #
  #   @example
  #     [1, 10, 11, 12, 2, 20, 21, 3, 30, 31, 32].group_by_chunks { _1 < 10 }
  #     # => { 1 => [10, 11, 12], 2 => [20, 21], 3 => [30, 31, 32] }
  #
  #   @note The first element must match the chunk condition.
  #
  #   @yield [Object]  object to analyze
  #   @yieldreturn [Boolean] chunk condition: begin a new chunk with this
  #     object as key if the condition returns true
  #   @return [Hash]
  def group_by_chunks
    fail(ArgumentError, "first element must match chunk condition") unless yield(first)
    slice_when { yield(_2) }.map { [_1.first, _1[1..]] }.to_h
  end

end
