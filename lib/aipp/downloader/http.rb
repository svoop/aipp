module AIPP
  class Downloader

    # Remote file via HTTP
    class HTTP < File
      ARCHIVE_MIME_TYPES = {
        'application/zip' => :zip,
        'application/x-zip-compressed' => :zip
      }.freeze

      def initialize(archive: nil, file:, type: nil, headers: {})
        @archive = URI(archive) if archive
        @file, @type, @headers = URI(file), type&.to_s, headers
        @digest = (archive || file).to_digest
      end

      # @param path [Pathname] directory where to write the fetched file
      # @return [File] fetched file
      def fetch_to(path)
        response = Excon.get((@archive || file).to_s, headers: @headers)
        fail NotFoundError if response.status == 404
        mime_type = ARCHIVE_MIME_TYPES.fetch(response.headers['Content-Type'], :dat)
        downloaded_file = path.join([@digest, mime_type].join('.'))
        ::File.write(downloaded_file, response.body)
        path.join(fetched_file).tap do |target|
          if @archive
            extract(file, from: downloaded_file, as: target)
            ::File.delete(downloaded_file)
          else
            ::File.rename(downloaded_file, target)
          end
        end
        self
      end

      private

      def name
        path = Pathname(file.path)
        path.basename(path.extname).to_s.blank_to_nil || @digest
      end

      def type
        @type || Pathname(file.path).extname[1..].blank_to_nil || fail("type must be declared")
      end
    end

  end
end
