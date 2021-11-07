module AIPP

  # AIP downloader infrastructure
  #
  # The downloader operates in the +storage+ directory where it creates two
  # subdirectories "sources" and "work". The initializer looks for the +source+
  # archive in "sources" and (if found) unzips its contents into "work". When
  # reading a +document+, the downloader looks for the +document+ in "work" and
  # (unless found) downloads it from +url+. HTML documents are parsed to
  # +Nokogiri::HTML5::Document+, PDF documents are parsed to +AIPP::PDF+.
  # Finally, the contents of "work" are written back to the +source+ archive.
  #
  # @example
  #   AIPP::Downloader.new(storage: options[:storage], source: "2018-11-08") do |downloader|
  #     html = downloader.read(
  #       document: 'ENR-5.1',
  #       url: 'https://www.sia.aviation-civile.gouv.fr/dvd/eAIP_08_NOV_2018/FRANCE/AIRAC-2018-11-08/html/eAIP/FR-ENR-5.1-fr-FR.html'
  #     )
  #     pdf = downloader.read(
  #       document: 'VAC-LFMV',
  #       url: 'https://www.sia.aviation-civile.gouv.fr/dvd/eAIP_08_NOV_2018/Atlas-VAC/PDF_AIPparSSection/VAC/AD/AD-2.LFMV.pdf'
  #     )
  #   end
  class Downloader

    # Error when URL results in "404 Not Found" HTTP status
    class NotFoundError < StandardError; end

    # @return [Pathname] directory to operate within
    attr_reader :storage

    # @return [String] name of the source archive (without extension ".zip")
    attr_reader :source

    # @return [Pathname] full path to the source archive
    attr_reader :source_file

    # @param storage [Pathname] directory to operate within
    # @param source [String] name of the source archive (without extension ".zip")
    def initialize(storage:, source:)
      @storage, @source = storage, source
      fail(ArgumentError, 'bad storage directory') unless Dir.exist? storage
      @source_file = sources_path.join("#{@source}.zip")
      prepare
      unzip if @source_file.exist?
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
    #   the URL, :html, :pdf, :xlsx, :ods or :csv
    # @return [Nokogiri::HTML5::Document, AIPP::PDF, Roo::Spreadsheet]
    def read(document:, url:, type: nil)
      type ||= Pathname(URI(url).path).extname[1..-1].to_sym
      file = work_path.join([document, type].join('.'))
      if file.exist?
        fail NotFoundError if file.empty?   # replay 404
      else
        verbose_info "Downloading #{document}"
        uri = URI.open(url)
        IO.copy_stream(uri, file)
      end
      convert file
    rescue OpenURI::HTTPError => error
      if error.message.match? /^404/
        FileUtils.touch file   # cache 404
        raise NotFoundError
      else
        raise error
      end
    end

    private

    def sources_path
      @storage.join('sources')
    end

    def work_path
      @storage.join('work')
    end

    def prepare
      teardown
      sources_path.mkpath
      work_path.mkpath
    end

    def teardown
      if work_path.exist?
        work_path.children.each(&:delete)
        work_path.delete
      end
    end

    def unzip
      Zip::File.open(source_file).each do |entry|
        entry.extract(work_path.join(entry.name))
      end
    end

    def zip
      backup_file = source_file.sub(/$/, '.old') if source_file.exist?
      source_file.rename(backup_file) if backup_file
      Zip::File.open(source_file, Zip::File::CREATE) do |zip|
        work_path.children.each do |entry|
          zip.add(entry.basename.to_s, entry) unless entry.basename.to_s[0] == '.'
        end
      end
      backup_file&.delete
    end

    def convert(file)
      case file.extname
        when '.html' then Nokogiri.HTML5(file)
        when '.pdf' then AIPP::PDF.new(file)
        when '.xlsx', '.ods', '.csv' then Roo::Spreadsheet.open(file.to_s)
      else
        fail(ArgumentError, "invalid document type")
      end
    end
  end
end
