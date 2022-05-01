module Nokogiri

  module PseudoClasses
    class Matches
      def matches(node_set, regexp)
        node_set.find_all { _1.content.match? /#{regexp}/ }
      end
    end
  end

  # Pseudo class which matches the content of each node set member against the
  # given regular expression.
  #
  # @example
  #   node.css('title:matches("\w+")', Nokogiri::MATCHES)
  MATCHES = PseudoClasses::Matches.new

  module XML
    class Element

      BOOLEANIZE_AS_TRUE_RE = /^(true|yes|oui|ja)$/i.freeze
      BOOLEANIZE_AS_FALSE_RE = /^(false|no|non|nein)$/i.freeze

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

      # Traverse all child elements and build a hash mapping the symbolized
      # child node name to the child content.
      #
      # @return [Hash]
      def contents
        @contents ||= elements.to_h { [_1.name.to_sym, _1.content] }
      end

      # Find this child element or add a new such element if none is found.
      #
      # The position to add is determined as follows:
      #
      # * If +after_css+ is given, its rules are applied in reverse order and
      #   the last matching rule defines the predecessor of the added child.
      # * If only +before_css+ is given, its rules are applied in order and
      #   the first matching rule defines the successor of the added child.
      # * If none of the above are given, the child is added at the end.
      #
      # @param name [Array<String>] name of the child element
      # @param after_css [Array<String>] array of CSS rules
      # @param before_css [Array<String>] array of CSS rules
      # @return [Nokogiri::XML::Element, nil] element or +nil+ if none found
      #   and no position to add a new one could be determined
      def find_or_add_child(name, after_css: nil, before_css: nil)
        at_css(name) or begin
          case
          when after_css
            at_css(*after_css.reverse).then do |predecessor|
              predecessor&.add_next_sibling("<#{name}/>")
            end&.first
          when before_css
            at_css(*before_css).then do |successor|
              successor&.add_previous_sibling("<#{name}/>")
            end&.first
          else
            add_child("<#{name}/>").first
          end
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
