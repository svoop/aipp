module AIPP
  module AIP

    class Runner < AIPP::Runner

      def effective_at
        AIPP.options.airac.effective.begin
      end

      def expiration_at
        AIPP.options.airac.effective.end
      end

      def run
        info("AIP AIRAC #{AIPP.options.airac.id} effective #{effective_at}", color: :green)
        read_config
        read_region
        read_parsers
        parse_sections
        if aixm.features.any?
          validate_aixm
          write_build
        end
        write_aixm(AIPP.options.output_file || output_file)
        write_config
      end

      private

      # Parse AIP by invoking the parser classes for the current region.
      def parse_sections
        super
        if AIPP.options.grouped_obstacles
          info("grouping obstacles")
          aixm.group_obstacles!
        end
      end

      # Write the AIXM document and context information.
      def write_build
        if AIPP.options.section
          super
        else
          info("writing build")
          builds_dir.mkpath
          build_file = builds_dir.join("#{AIPP.options.airac.date.xmlschema}.zip")
          Dir.mktmpdir do |tmp_dir|
            tmp_dir = Pathname(tmp_dir)
            # AIXM/OFMX file
            AIXM.config.mid = true
            File.write(tmp_dir.join(output_file), aixm.to_xml)
            # Build details
            File.write(
              tmp_dir.join('build.yaml'), {
                version: AIPP::VERSION,
                config: AIPP.config,
                options: AIPP.options,
              }.to_yaml
            )
            # Manifest
            manifest = ['AIP','Feature', 'Comment', 'Short Uid Hash', 'Short Feature Hash'].to_csv
            manifest += aixm.features.map do |feature|
              xml = feature.to_xml
              element = xml.first_match(/<(\w{3})\s/)
              [
                feature.source.split('|')[2],
                element,
                xml.match(/<!-- (.*?) -->/)[1],
                AIXM::PayloadHash.new(xml.match(%r(<#{element}Uid\s.*?</#{element}Uid>)m).to_s).to_uuid[0,8],
                AIXM::PayloadHash.new(xml).to_uuid[0,8]
              ].to_csv
            end.sort.join
            File.write(tmp_dir.join('manifest.csv'), manifest)
            # Zip it
            build_file.delete if build_file.exist?
            Zip::File.open(build_file, Zip::File::CREATE) do |zip|
              tmp_dir.children.each do |entry|
                zip.add(entry.basename.to_s, entry) unless entry.basename.to_s[0] == '.'
              end
            end
          end
        end
      end
    end

  end
end
