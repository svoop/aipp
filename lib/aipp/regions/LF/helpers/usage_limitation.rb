module AIPP
  module LF
    module Helpers
      module UsageLimitation

        # Map limitation type descriptions to AIXM limitation, realm and remarks
        LIMITATION_TYPES = {
          'OFF' => nil,   # skip decommissioned aerodromes/helistations
          'CAP' => { limitation: :permitted, realm: :civilian },
          'ADM' => { limitation: :permitted, realm: :other, remarks: "Goverment ACFT only / Réservé aux ACFT de l'État" },
          'MIL' => { limitation: :permitted, realm: :military },
          'PRV' => { limitation: :reservation_required, realm: :civilian },
          'RST' => { limitation: :reservation_required, realm: :civilian },
          'TPD' => { limitation: :reservation_required, realm: :civilian }
        }.freeze

      end
    end
  end
end
