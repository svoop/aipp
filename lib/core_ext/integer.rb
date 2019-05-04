class Integer

  # Iterates the given block, passing in increasing or decreasing values to and
  # including limit
  #
  # If no block is given, an Enumerator is returned instead.
  #
  # @example
  #   10.up_or_downto(12).to_a   # => [10, 11, 12]
  #   10.upto(12).to_a           # => [10, 11, 12]
  #   10.up_or_downto(8).to_a    # => [10, 9, 8]
  #   10.downto(8).to_a          # => [10, 9, 8]
  def up_or_downto(limit)
    self > limit ? self.downto(limit) : self.upto(limit)
  end
end
