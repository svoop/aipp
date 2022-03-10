module AIPP
  module Patcher

    def self.included(base)
      base.extend(ClassMethods)
      base.class_variable_set(:@@patches, {})
    end

    module ClassMethods
      def patches
        class_variable_get(:@@patches)
      end

      def patch(klass, attribute, &block)
        (patches[self] ||= []) << [klass, attribute, block]
      end
    end

    def attach_patches
      verbose_info_method = method(:verbose_info)
      self.class.patches[self.class]&.each do |(klass, attribute, block)|
        klass.instance_eval do
          alias_method :"original_#{attribute}=", :"#{attribute}="
          define_method(:"#{attribute}=") do |value|
            error = catch :abort do
              value = block.call(self, value)
              verbose_info_method.call("Patching #{self.inspect} with #{attribute}=#{value.inspect}", color: :magenta)
            end
            fail "patching #{self.inspect} with #{attribute}=#{value.inspect} failed: #{error}" if error
            send(:"original_#{attribute}=", value)
          end
        end
      end
      self
    end

    def detach_patches
      self.class.patches[self.class]&.each do |(klass, attribute, _)|
        klass.instance_eval do
          remove_method :"#{attribute}="
          alias_method :"#{attribute}=", :"original_#{attribute}="
          remove_method :"original_#{attribute}="
        end
      end
      self
    end

  end
end
