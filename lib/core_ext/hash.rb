class Hash

  # Returns a value from the hash for the matching key
  #
  # Similar to +fetch+, search the hash keys for the search string and return
  # the corresponding value. Unlike +fetch+, however, if a hash key is a Regexp,
  # the search argument is matched against this Regexp. The hash is searched
  # in its natural order.
  #
  # @example
  #   h = { /aa/ => :aa, /a/ => :a, 'b' => :b }
  #   h.metch('abc')          # => :a
  #   h.metch('bcd')          # => KeyError
  #   h.metch('b')            # => :b
  #   h.metch('x', :foobar)   # => :foobar
  #
  # @param search [String] string to search or matche against
  # @param default [Object] fallback value if no key matched
  # @return [Object] hash value
  # @raise [KeyError] no key matched and no default given
  def metch(search, default=:__n_o_n_e__)
    fetch search
  rescue KeyError
    each do |key, value|
      next unless key.is_a? Regexp
      return value if key.match? search
    end
    raise(KeyError, "no match found: #{search.inspect}") if default == :__n_o_n_e__
    default
  end

  # Compile a titles/texts hash to remarks Markdown string
  #
  # @example
  #   { name: 'foobar', ignore: => nil, 'count/quantité' => 3 }.to_remarks
  #   # => "NAME\nfoobar\n\nCOUNT/QUANTITÉ\n3"
  #   { ignore: nil, ignore_as_well: "" }.to_remarks
  #   # => nil
  #
  # @return [String, nil] compiled remarks
  def to_remarks
    map { |k, v| "**#{k.to_s.upcase}**\n#{v}" unless v.blank? }.
      compact.
      join("\n\n").
      blank_to_nil
  end
end
