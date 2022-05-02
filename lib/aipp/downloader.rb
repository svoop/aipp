module AIPP

  # AIP downloader infrastructure
  #
  # The downloader operates in the +storage+ directory where it creates two
  # subdirectories "sources" and "work". The initializer looks for the +source+
  # archive in "sources" and (if found) unzips its contents into "work". When
  # reading a +document+, the downloader looks for the +document+ in "work" and
  # (unless found or clean option set) downloads it from +url+ and reads them.
  # Finally, the contents of "work" are written back to the +source+ archive.
  #
  # The following protocols are recognized:
  #
  # [HTTPS or HTTP]
  #   Connect to a web server using {URI#open}[https://www.rubydoc.info/gems/open-uri].
  # [FTPS or FTP]
  #   Connect to a file server using {URI#open}[https://www.rubydoc.info/gems/open-uri].
  #
  # The following file type extensions are recognised:
  #
  # [.xml] Parsed by Nokogiri returning an instance of {Nokogiri::XML::Document}[https://www.rubydoc.info/gems/nokogiri/Nokogiri/XML/Document]
  # [.html] Parsed by Nokogiri returning an instance of {Nokogiri::HTML5::Document}[https://www.rubydoc.info/gems/nokogiri/Nokogiri/HTML5/Document]
  # [.pdf] Converted to text – see {AIPP::PDF}
  # [.xlsx] Parsed by Roo returning an instance of {Roo::Excelx}[https://www.rubydoc.info/gems/roo/Roo/Excelx]
  # [.ods] Parsed by Roo returning an instance of {Roo::OpenOffice}[https://www.rubydoc.info/gems/roo/Roo/OpenOffice]
  # [.csv] Parsed by Roo returning an instance of {Roo::CSV}[https://www.rubydoc.info/gems/roo/Roo/CSV]
  # [.txt] Instance of +String+
  #
  # @example
  #   AIPP::Downloader.new(storage: AIPP.options.storage, source: "2018-11-08") do |downloader|
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
    include AIPP::Debugger

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
      if @source_file.exist?
        if AIPP.options.clean
          @source_file.delete
        else
          unpack
        end
      end
      yield self
      pack
    ensure
      teardown
    end

    # @return [String]
    def inspect
      "#<AIPP::Downloader>"
    end

    # Download and read +document+
    #
    # @param document [String] document to read (without extension)
    # @param url [String] URL to download the document from
    # @param type [Symbol, nil] document type: +nil+ (default) to derive it from
    #   the URL, :xml, :ofmx, :html, :pdf, :xlsx, :ods or :csv
    # @return [Nokogiri::HTML5::Document, AIPP::PDF, Roo::Spreadsheet, String]
    def read(document:, url:, type: nil)
      uri = URI(url)
      type ||= Pathname(uri.path).extname[1..-1].to_sym
      archive, file = nil, work_path.join([document, type].join('.'))
      archive, file = file, work_path.join(Pathname(uri.fragment).basename) if type == :zip
      unless file.exist?
        verbose_info "downloading #{document}"
        IO.copy_stream(URI.open(url), archive || file)
        if archive
          extract(archive, only_entry: uri.fragment) or fail "`#{uri.fragment}' not found in archive"
          archive.delete
        end
      end
      convert file
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

    def unpack
      extract(source_file) or fail
    end

    def pack
      backup_file = source_file.sub(/$/, '.old') if source_file.exist?
      source_file.rename(backup_file) if backup_file
      Zip::File.open(source_file, Zip::File::CREATE) do |zip|
        work_path.children.each do |entry|
          zip.add(entry.basename.to_s, entry) unless entry.basename.to_s[0] == '.'
        end
      end
      backup_file&.delete
    end

    def extract(archive, only_entry: nil)
      case archive.extname
        when '.zip' then unzip(archive, only_entry: only_entry)
        else fail(ArgumentError, "unrecognized archive type")
      end
    end

    # @return [Boolean] whether at least one file was extracted
    def unzip(archive, only_entry:)
      Zip::File.open(archive).inject(false) do |_, entry|
        case
        when only_entry && only_entry == entry.name
          break !!entry.extract(work_path.join(Pathname(entry.name).basename))
        when !only_entry
          !!entry.extract(work_path.join(entry.name))
        else
          false
        end
      end
    end

    def convert(file)
      case file.extname
        when '.xml', '.ofmx' then Nokogiri.XML(File.open(file), &:noblanks)
        when '.html' then Nokogiri.HTML5(File.open(file))
        when '.pdf' then AIPP::PDF.new(file)
        when '.xlsx', '.ods', '.csv' then Roo::Spreadsheet.open(file.to_s)
        when '.txt' then File.read(file)
        else fail(ArgumentError, "unrecognized file type")
      end
    end
  end
end
