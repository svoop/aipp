module AIPP
  module Callback

    # Simple before callbacks for any method call
    #
    # @example
    #   class Shoe
    #     attr_reader :size
    #     def size=(value)
    #       fail ArgumentError unless (30..50).include? value
    #       @size = value
    #     end
    #   end
    #
    #   shoe = Shoe.new
    #   shoe.size = 10   # => ArgumentError
    #
    #   Shoe.extend AIPP::Callback
    #   Shoe.before :size= do |object, method, args|
    #     [42] if args.first < 30
    #   end
    #   shoe = Shoe.new
    #   shoe.size = 10
    #   shoe.size   # => 42
    #   shoe.size = 30
    #   shoe.size   # => 30
    def before(method, &block)
      aliased_method = :"__#{method}"
      alias_method aliased_method, method
      private aliased_method
      define_method method do |*args|
        updated_args = block.call(self, method, args)
        updated_args ||= args
        send(aliased_method, *updated_args)
      end
    end

  end
end
