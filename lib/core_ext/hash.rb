class Hash

  # Returns a value from the hash for the matching key
  #
  # Similar to +fetch+, search the hash keys for the search string and return
  # the corresponding value. Unlike +fetch+, however, if a hash key is a Regexp,
  # the search string is matched against this Regexp. The hash is searched
  # in it's natural order.
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
  def metch(search, default=nil)
    fetch search
  rescue KeyError
    each do |key, value|
      next unless key.is_a? Regexp
      return value if search.match? key
    end
    default ? default : raise(KeyError, "no match found: #{search.inspect}")
  end

end
