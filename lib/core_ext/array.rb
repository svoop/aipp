class Array

  # Convert array of namespaces to constant.
  #
  # @example
  #   %i(AIPP AIP Base).constantize   # => AIPP::AIP::Base
  #
  # @return [Class, Module] converted array
  def constantize
    map(&:to_s).join('::').constantize
  end

  # Consolidate array of possibly overlapping ranges.
  #
  # @example
  #   [15..17, 7..11, 12..13, 8..12, 12..13].consolidate_ranges
  #   # => [7..13, 15..17]
  #
  # @param [Symbol, nil] method to call on range members for comparison
  # @return [Array] consolidated array
  def consolidate_ranges(method=:itself)
    uniq.sort_by { [_1.begin, _1.end] }.then do |ranges|
      consolidated, a = [], ranges.first
      Array(ranges[1..]).each do |b|
        if a.end.send(method) >= b.begin.send(method)   # overlapping
          a = (a.begin..(a.end.send(method) > b.end.send(method) ? a.end : b.end))
        else   # not overlapping
          consolidated << a
          a = b
        end
      end
      consolidated << a
    end.compact
  end

end
