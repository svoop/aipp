module AIPP

  # AIP downloader infrastructure
  #
  # The downloader operates in the +storage+ directory where it creates two
  # subdirectories "sources" and "work". The initializer looks for the +source+
  # archive in "sources" and (if found) unpacks its contents into "work". When
  # reading a +document+, the downloader looks for the +document+ in "work" and
  # (if not found or the clean option is set) downloads it from +origin+.
  # Finally, the contents of "work" are packed back into the +source+ archive.
  #
  # Origins are defined as instances of downloader origin objects:
  #
  # * {AIXM::Downloader::File} – local file or archive
  # * {AIXM::Downloader::HTTP} – remote file or archive via HTTP
  # * {AIXM::Downloader::GraphQL} – GraphQL query
  #
  # The following archives are recognized:
  #
  # [.zip] ZIP archive
  #
  # The following file types are recognised:
  #
  # [.ofmx] Parsed by Nokogiri returning an instance of {Nokogiri::XML::Document}[https://www.rubydoc.info/gems/nokogiri/Nokogiri/XML/Document]
  # [.xml] Parsed by Nokogiri returning an instance of {Nokogiri::XML::Document}[https://www.rubydoc.info/gems/nokogiri/Nokogiri/XML/Document]
  # [.html] Parsed by Nokogiri returning an instance of {Nokogiri::HTML5::Document}[https://www.rubydoc.info/gems/nokogiri/Nokogiri/HTML5/Document]
  # [.pdf] Converted to text – see {AIPP::PDF}
  # [.json] Deserialized JSON e.g. as response to a GraphQL query
  # [.xlsx] Parsed by Roo returning an instance of {Roo::Excelx}[https://www.rubydoc.info/gems/roo/Roo/Excelx]
  # [.ods] Parsed by Roo returning an instance of {Roo::OpenOffice}[https://www.rubydoc.info/gems/roo/Roo/OpenOffice]
  # [.csv] Parsed by Roo returning an instance of {Roo::CSV}[https://www.rubydoc.info/gems/roo/Roo/CSV]
  # [.txt] Instance of +String+
  #
  # @example
  #   AIPP::Downloader.new(storage: AIPP.options.storage, source: "2018-11-08") do |downloader|
  #     html = downloader.read(
  #       document: 'ENR-5.1',
  #       origin: AIPP::Downloader::HTTP.new(
  #         file: 'https://www.sia.aviation-civile.gouv.fr/dvd/eAIP_08_NOV_2018/FRANCE/AIRAC-2018-11-08/html/eAIP/FR-ENR-5.1-fr-FR.html'
  #       )
  #     )
  #     pdf = downloader.read(
  #       document: 'VAC-LFMV',
  #       origin: AIPP::Downloader::HTTP.new(
  #         file: 'https://www.sia.aviation-civile.gouv.fr/dvd/eAIP_08_NOV_2018/Atlas-VAC/PDF_AIPparSSection/VAC/AD/AD-2.LFMV.pdf'
  #       )
  #     )
  #   end
  class Downloader
    include AIPP::Debugger

    # Error raised when any kind of downloader fails to find the resource e.g.
    # because the local file does not exist or the remote file is unavailable.
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
    # @param origin [AIPP::Downloader::File, AIPP::Downloader::HTTP,
    #   AIPP::Downloader::GraphQL] origin to download the document from
    # @return [Object]
    def read(document:, origin:)
      file = work_path.join(origin.fetched_file)
      unless file.exist?
        verbose_info "downloading #{document}"
        origin.fetch_to(work_path)
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
        when '.xml', '.ofmx' then Nokogiri.XML(::File.open(file), &:noblanks)
        when '.html' then Nokogiri.HTML5(::File.open(file))
        when '.json' then JSON.load_file(file, symbolize_names: true)
        when '.pdf' then AIPP::PDF.new(file)
        when '.xlsx', '.ods' then Roo::Spreadsheet.open(file.to_s)
        when '.csv' then Roo::Spreadsheet.open(file.to_s, csv_options: { col_sep: separator(file) })
        when '.txt' then ::File.read(file)
        else fail(ArgumentError, "unrecognized file type")
      end
    end

    # @return [String] most likely separator character of CSV and similar files
    def separator(file)
      content = file.read
      %W(, ; \t).map { [content.scan(_1).count, _1] }.sort.last.last
    end

  end
end
