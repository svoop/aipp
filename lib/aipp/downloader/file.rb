module AIPP
  class Downloader

    # Local file
    class File
      attr_reader :file

      def initialize(archive: nil, file:, type: nil)
        @archive = Pathname(archive) if archive
        @file, @type = Pathname(file), type&.to_s
      end

      def fetch_to(path)
        path.join(fetched_file).tap do |target|
          if @archive
            fail NotFoundError unless @archive.exist?
            extract(file, from: @archive, as: target)
          else
            fail NotFoundError unless file.exist?
            FileUtils.cp(file, target)
          end
        end
        self
      end

      def fetched_file
        [name, type].join('.')
      end

      private

      def name
        file.basename(file.extname).to_s
      end

      def type
        @type || file.extname[1..] || fail("type must be declared")
      end

      def extract(file, from:, as:)
        if respond_to?(extractor = 'un' + from.extname[1..], true)
          send(extractor, file, from: from, as: as) or fail NotFoundError
        else
          fail "archive type not recognized"
        end
      end

      # @return [Boolean] whether a file was extracted
      def unzip(file, from:, as:)
        Zip::File.open(from).inject(nil) do |_, entry|
          if file.to_s == entry.name
            break entry.extract(as)
          end
        end
      end
    end

  end
end
