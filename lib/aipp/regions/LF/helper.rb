module AIPP
  module LF
    module Helper

      AIPS = %w(
        ENR-4.1
        ENR-4.3
        ENR-5.1
      ).freeze

      def url(aip:)
        "https://www.sia.aviation-civile.gouv.fr/dvd/eAIP_%s/FRANCE/AIRAC-%s/html/eAIP/FR-%s-fr-FR.html" % [
          options[:airac].date.strftime('%d_%^b_%Y'),   # 04_JAN_2018
          options[:airac].date.xmlschema,               # 2018-01-04
          aip                                           # ENR-5.1
        ]
      end

      def cleanup(node:)
        node.tap do |root|
          root.css('del').each { |n| n.remove }   # remove deleted entries
        end
      end

      def organisation_lf
        @organisation_lf ||= AIXM.organisation(
          region: 'LF',
          name: 'FRANCE',
          type: 'S'
        ).tap do |organisation|
          organisation.id = 'LF'
        end
      end

    end
  end
end
