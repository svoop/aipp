module AIPP

  # AIP downloader infrastructure
  #
  # The downloader operates in the +storage+ directory where it creates two
  # subdirectories "archive" and "work". The initializer looks for +archive+
  # in "archives" and (if found) unzips its contents into "work". When reading
  # a +document+, the downloader looks for the +document+ in "work" and (unless
  # unless found) downloads it from +url+. HTML documents are parsed to
  # +Nokogiri::HTML5::Document+, PDF documents are converted to +String+
  # containing the text only. Finally, the contents of "work" are written back
  # to +archive+.
  #
  # @example
  #   AIPP::Downloader.new(storage: options[:storage], archive: "2018-11-08") do |downloader|
  #     html = downloader.read(document: 'ENR-2.1.html', url: 'https://...')
  #   end
  class Downloader

    # @return [Pathname] directory to operate within
    attr_reader :storage

    # @return [String] name of the archive (without extension ".zip")
    attr_reader :archive

    # @return [Pathname] full path to the archive
    attr_reader :archive_file

    # @param storage [Pathname] directory to operate within
    # @param archive [String] name of the archive (without extension ".zip")
    def initialize(storage:, archive:)
      @storage, @archive = storage, archive
      fail(ArgumentError, 'bad storage directory') unless Dir.exist? storage
      @archive_file = archives_path.join("#{@archive}.zip")
      prepare
      unzip if @archive_file.exist?
      yield self
      zip
    ensure
      teardown
    end

    # Download and read +document+
    #
    # @param document [String] document to read (without extension)
    # @param url [String] URL to download the document from
    # @param type [Symbol, nil] document type: +nil+ (default) to derive it from
    #   the URL, :html, or :pdf
    # @return [Nokogiri::HTML5::Document, String] HTML as Nokogiri document,
    #   PDF or TXT as String
    def read(document:, url:, type: nil)
      type ||= Pathname(URI(url).path).extname[1..-1].to_sym
      file = work_path.join([document, type].join('.'))
      unless file.exist?
        debug "Downloading #{document}"
        IO.copy_stream(Kernel.open(url), file)
      end
      convert file
    end

    private

    def archives_path
      @storage.join('archives')
    end

    def work_path
      @storage.join('work')
    end

    def prepare
      teardown
      archives_path.mkpath
      work_path.mkpath
    end

    def teardown
      if work_path.exist?
        work_path.children.each(&:delete)
        work_path.delete
      end
    end

    def unzip
      Zip::File.open(archive_file).each do |entry|
        entry.extract(work_path.join(entry.name))
      end
    end

    def zip
      backup_file = archive_file.sub(/$/, '.old') if archive_file.exist?
      archive_file.rename(backup_file) if backup_file
      Zip::File.open(archive_file, Zip::File::CREATE) do |zip|
        work_path.children.each do |entry|
          zip.add(entry.basename.to_s, entry) unless entry.basename.to_s[0] == '.'
        end
      end
      backup_file&.delete
    end

    def convert(file)
      case file.extname
      when '.txt'
        IO.read(file)
      when '.html'
        Nokogiri.HTML5(file)
      when '.pdf'
        cache(file.sub_ext('.txt')) do
          PDF::Reader.new(file).pages.map(&:text).join("\n\f\n")
        end
      else
        fail(ArgumentError, "invalid document type")
      end
    end

    def cache(file)
      if file.exist?
        convert(file)
      else
        yield.tap { |c| File.write(file, c) }
      end
    end
  end
end
