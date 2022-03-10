module AIPP
  module LS
    module Helpers
      module Base

        using AIXM::Refinements

        # Mandatory Interface

        def url_for(document)
          sql = case document
          when 'ENR'
            <<~END
              SELECT id, effectiveFrom, validUntil, notam
                FROM notam
                WHERE id LIKE '%-LSAS' AND
                  validUntil > CAST('#{AIPP.options.effective_at.utc}' AS datetime)
                ORDER BY effectiveFrom
            END
          when 'AD'
            fail "not yet implemented"
          else
            fail "document not recognized"
          end
          "mysql://%s?command=%s" % [
            ENV.fetch('DB_URL', 'cloudsqlproxy@127.0.0.1:33306/notam'),
            CGI.escape(sql)
          ]
        end

        # Templates

        def organisation_lf
          unless AIPP.cache.organisation_lf
            AIPP.cache.organisation_lf = AIXM.organisation(
              source: source(position: 1, document: "GEN-3.1"),
              name: 'SWITZERLAND',
              type: 'S'
            ).tap do |organisation|
              organisation.id = 'LS'
            end
            add AIPP.cache.organisation_ls
          end
          AIPP.cache.organisation_ls
        end

      end
    end
  end
end
