module AIPP

  # Topologically sortable hash for dealing with dependencies
  #
  # Example:
  #   dependency_hash = THash[
  #     dns: %i(net),
  #     webserver: %i(dns logger),
  #     net: [],
  #     logger: []
  #   ]
  #   # Sort to resolve dependencies of the entire hash
  #   dependency_hash.tsort         # => [:net, :dns, :logger, :webserver]
  #   # Sort to resolve dependencies of one node only
  #   dependency_hash.tsort(:dns)   # => [:net, :dns]
  class THash < Hash
    include TSort

    alias_method :tsort_each_node, :each_key

    def tsort_each_child(node, &block)
     fetch(node).each(&block)
    end

    def tsort(node=nil)
      if node
        subhash = subhash_for node
        super().select { |n| subhash.include? n }
      else
        super()
      end
    end

    private

    def subhash_for(node, memo=[])
      memo.tap do |m|
        fail TSort::Cyclic if m.include? node
        m << node
        fetch(node).each { |n| subhash_for(n, m) }
      end
    end

  end

end
