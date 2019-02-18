module AIPP
  module Patcher

    def patch(klass, attribute)
      @patches ||= []
      @patches << [klass, attribute]
      klass.instance_eval do
        alias_method :"original_#{attribute}=", :"#{attribute}="
        define_method(:"#{attribute}=") do |value|
          catch :abort do
            value = yield(self, value)
            info("PATCH: #{self.inspect}", color: :magenta)
          end
          send(:"original_#{attribute}=", value)
        end
      end
    end

    def remove_patches
      if @patches
        @patches.each do |(klass, attribute)|
          klass.instance_eval do
            alias_method :"#{attribute}=", :"original_#{attribute}="
            remove_method :"original_#{attribute}="
          end
        end
        @patches.clear
      end
    end

  end
end
