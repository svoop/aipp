module AIPP

  # AIP downloader infrastructure
  #
  # The downloader operates in the +storage+ directory where it creates two
  # subdirectories "archive" and "work". The initializer looks for +archive+
  # in "archives" and (if found) unzips its contents into "work". When reading
  # a +document+, the downloader looks for the +document+ in "work" and
  # (unless found) downloads it from +url+. HTML documents are parsed to
  # +Nokogiri::HTML5::Document+, PDF documents are parsed to +AIPP::PDF+.
  # Finally, the contents of "work" are written back to +archive+.
  #
  # @example
  #   AIPP::Downloader.new(storage: options[:storage], archive: "2018-11-08") do |downloader|
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
    # @return [Nokogiri::HTML5::Document, AIPP::PDF]
    def read(document:, url:, type: nil)
      type ||= Pathname(URI(url).path).extname[1..-1].to_sym
      file = work_path.join([document, type].join('.'))
      unless file.exist?
        verbose_info "Downloading #{document}"
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
        when '.html' then Nokogiri.HTML5(file)
        when '.pdf' then AIPP::PDF.new(file)
      else
        fail(ArgumentError, "invalid document type")
      end
    end
  end
end
