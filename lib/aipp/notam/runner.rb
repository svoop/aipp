module AIPP
  module NOTAM

    class Runner < AIPP::Runner

      def effective_at
        AIPP.options.effective_at
      end

      def run
        info("NOTAM effective #{effective_at}", color: :green)
        read_config
        read_region
        read_parsers
        parse_sections
        validate_aixm
        write_aixm(aixm_file)
        write_config
      end

    end

  end
end
