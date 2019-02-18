module AIPP
  module LF
    module Helpers
      module URL

        # @param aip_file [String] e.g. ENR-5.1, AD-2.LFMV or VAC-LFMV
        def url_for(aip_file)
          case aip_file
          when /^VAC\-(\w+)/
            "https://www.sia.aviation-civile.gouv.fr/dvd/eAIP_%s/Atlas-VAC/PDF_AIPparSSection/VAC/AD/AD-2.%s.pdf" % [
              options[:airac].date.strftime('%d_%^b_%Y'),   # 04_JAN_2018
              $1
            ]
          else
            "https://www.sia.aviation-civile.gouv.fr/dvd/eAIP_%s/FRANCE/AIRAC-%s/html/eAIP/FR-%s-fr-FR.html" % [
              options[:airac].date.strftime('%d_%^b_%Y'),   # 04_JAN_2018
              options[:airac].date.xmlschema,               # 2018-01-04
              aip_file
            ]
          end
        end

      end
    end
  end
end
