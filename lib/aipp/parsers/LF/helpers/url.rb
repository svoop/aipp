module AIPP
  module Helpers
    module URL

      def url
        "https://www.sia.aviation-civile.gouv.fr/dvd/eAIP_%s/FRANCE/AIRAC-%s/html/eAIP/FR-%s-fr-FR.html" % [
          aixm.effective_at.strftime('%d_%^b_%Y'),   # 04_JAN_2018
          aixm.effective_at.to_date.xmlschema,       # 2018-01-04
          @aip                                       # ENR-5.1
        ]
      end

    end
  end
end
