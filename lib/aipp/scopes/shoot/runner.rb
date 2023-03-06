module AIPP
  module SHOOT

    class Runner < AIPP::Runner

      def effective_at
        AIPP.options.effective_at
      end

      def expiration_at
        effective_at + 86399
      end

      def run
        info("SHOOT effective #{effective_at}", color: :green)
        read_config
        read_region
        read_parsers
        parse_sections
        if aixm.features.any?
          validate_aixm
        end
        write_aixm(AIPP.options.output_file || output_file)
        write_config
      end

    end

  end
end
