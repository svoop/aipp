module AIPP
  module Helpers
    module HTML

      def cleanup(node)
        node.tap do |root|
          root.css('del').each { |n| n.remove }   # remove deleted entries
        end
      end

    end
  end
end
