module Nokogiri
  module XML
    class Element

      BOOLEANIZE_AS_TRUE_RE = /^(true|yes|oui|ja)$/i.freeze
      BOOLEANIZE_AS_FALSE_RE = /^(false|no|non|nein)$/i.freeze

      # Traverse all child elements and build a hash mapping the symbolized
      # child node name to the child content.
      #
      # @return [Hash]
      def contents
        @contents ||= elements.to_h { [_1.name.to_sym, _1.content] }
      end

      # Shortcut to query +contents+ array which accepts both String or
      # Symbol queries as well as query postfixes.
      #
      # @example query optional content for :key
      #   element.(:key)    # same as element.contents[:key]
      #
      # @example query mandatory content for :key
      #   element.(:key!)   # fails if the key does not exist
      #
      # @example query boolean content for :key
      #   element.(:key?)   # returns true or false
      #
      # @see +BOOLEANIZE_AS_TRUE_RE+ and +BOOLEANIZE_AS_FALSE_RE+ define the
      #   regular expressions which convert the content to boolean. Furthermore,
      #   nil is interpreted as false as well.
      #
      # @raise KeyError mandatory or boolean content not found
      # @return [String, Boolean]
      def call(query)
        case query
          when /\?$/ then booleanize(contents.fetch(query[...-1].to_sym))
          when /\!$/ then contents.fetch(query[...-1].to_sym)
          else contents[query.to_sym]
        end
      end

      private

      def booleanize(content)
        case content
          when nil then false
          when BOOLEANIZE_AS_TRUE_RE then true
          when BOOLEANIZE_AS_FALSE_RE then false
          else fail(KeyError, "`#{content}' not recognized as boolean")
        end
      end
    end
  end
end
