module Enumerable

  # !method split(object=nil, &block)
  #   Divides an enumerable into sub-enumerables based on a delimiter,
  #   returning an array of these sub-enumerables.
  #
  #   @example
  #     [1, 2, 0, 3, 4].split { |e| e == 0 }   # => [[1, 2], [3, 4]]
  #     [1, 2, 0, 3, 4].split(0)               # => [[1, 2], [3, 4]]
  #     [0, 0, 1, 0, 2].split(0)               # => [[], [] [1], [2]]
  #     [1, 0, 0, 2, 3].split(0)               # => [[1], [], [2], [3]]
  #     [1, 0, 2, 0, 0].split(0)               # => [[1], [2]]
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
