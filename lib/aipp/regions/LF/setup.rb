module AIPP
  module LF
    class Setup < AIP

      def parse
        AIXM.config.voice_channel_separation = :any
      end

    end
  end
end
