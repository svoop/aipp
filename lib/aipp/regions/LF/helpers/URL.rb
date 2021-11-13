module AIPP
  module LF
    module Helpers
      module URL

        # @param aip_file [String] e.g. ENR-5.1, AD-2.LFMV, VAC-LFMV or AD
        def url_for(aip_file)
          sia_date = options[:airac].date.strftime('%d_%^b_%Y')   # 04_JAN_2018
          xml_date = options[:airac].date.xmlschema               # 2018-01-04
          case aip_file
          when /^Obstacles/
            "https://www.sia.aviation-civile.gouv.fr/dvd/eAIP_%s/FRANCE/%s" % [
              sia_date,
              aip_file
            ]
          when /^VAC\-(\w+)/
            "https://www.sia.aviation-civile.gouv.fr/dvd/eAIP_%s/Atlas-VAC/PDF_AIPparSSection/VAC/AD/AD-2.%s.pdf" % [
              sia_date,
              $1
            ]
          when /^[A-Z]+-/
            "https://www.sia.aviation-civile.gouv.fr/dvd/eAIP_%s/FRANCE/AIRAC-%s/html/eAIP/FR-%s-fr-FR.html" % [
              sia_date,
              xml_date,
              aip_file
            ]
          else
            "XML_SIA_FR-OM_%s.xml" % [
              xml_date
            ]
          end
        end

      end
    end
  end
end
