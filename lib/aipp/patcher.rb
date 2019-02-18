module AIPP
  module Patcher

    def self.included(klass)
      klass.extend(ClassMethods)
      klass.class_variable_set(:@@patches, {})
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
      parser = self
      self.class.patches[self.class]&.each do |(klass, attribute, block)|
        klass.instance_eval do
          alias_method :"original_#{attribute}=", :"#{attribute}="
          define_method(:"#{attribute}=") do |value|
            catch :abort do
              value = block.call(parser, self, value)
              debug("PATCH: #{self.inspect}", color: :magenta)
            end
            send(:"original_#{attribute}=", value)
          end
        end
      end
      self
    end

    def detach_patches
      self.class.patches[self.class]&.each do |(klass, attribute, _)|
        klass.instance_eval do
          alias_method :"#{attribute}=", :"original_#{attribute}="
          remove_method :"original_#{attribute}="
        end
      end
      self
    end

  end
end
