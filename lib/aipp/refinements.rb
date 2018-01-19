module AIPP
  module Refinements

    refine Kernel do
      def warn(message, binding=nil)
        super(message)
        if $DEBUG && binding
          binding.pry
        end
      end
    end

    refine String do
      ##
      # Convert blank strings to +nil+
      def blank_to_nil
        match?(/\A\s*\z/) ? nil : self
      end
    end

    refine NilClass do
      ##
      # Companion to String#blank_to_nil
      def blank_to_nil
        self
      end
    end

    refine Array do
      ##
      # Split an array into nested arrays at the pattern (similar to +String#split+)
      def split(pattern)
        [].tap do |array|
          nested_array = []
          each do |element|
            if pattern === element
              array << nested_array
              nested_array = []
            else
              nested_array << element
            end
          end
          array << nested_array
          array.pop while array.last == []
        end
      end
    end

  end
end
