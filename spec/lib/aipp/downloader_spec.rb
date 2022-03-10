require_relative '../../spec_helper'

describe AIPP::Downloader do
  let :tmp_dir do
    Pathname(Dir.mktmpdir).tap do |tmp_dir|
      (sources_dir = tmp_dir.join('sources')).mkpath
      FileUtils.cp(fixtures_path.join('downloader', 'source.zip'), sources_dir)
    end
  end

  after do
    FileUtils.rm_rf(tmp_dir)
  end

  describe :read do
    context "source archive does not exist" do
      it "creates the source archive" do
        URI.stub(:open, File.open(fixtures_path.join('downloader', 'new.html'))) do
          subject = AIPP::Downloader.new(storage: tmp_dir, source: 'new-source') do |downloader|
            _(File.exist?(tmp_dir.join('work'))).must_equal true
            downloader.read(document: 'new', url: 'http://localhost/new.html')
          end
          _(zip_entries(subject.source_file)).must_equal %w(new.html)
          _(subject.send(:sources_path).children.count).must_equal 2
        end
      end
    end

    context "source archive does exist" do
      it "unzips and uses the source archive" do
        URI.stub(:open, File.open(fixtures_path.join('downloader', 'new.html'))) do
          subject = AIPP::Downloader.new(storage: tmp_dir, source: 'source') do |downloader|
            _(File.exist?(tmp_dir.join('work'))).must_equal true
            _(File.exist?(tmp_dir.join('sources', downloader.instance_variable_get('@source_file')))).must_equal true
            downloader.read(document: 'new', url: 'http://localhost/new.html').tap do |content|
              _(content).must_be_instance_of Nokogiri::HTML5::Document
              _(content.text).must_match(/fixture-html-new/)
            end
          end
          _(zip_entries(subject.source_file)).must_equal %w(new.html one.html two.html)
          _(subject.send(:sources_path).children.count).must_equal 1
        end
      end

      it "deletes the source archive on clean run" do
        AIPP.options.clean = true
        AIPP::Downloader.new(storage: tmp_dir, source: 'source') do |downloader|
          _(File.exist?(tmp_dir.join('work'))).must_equal true
          _(File.exist?(tmp_dir.join('sources', downloader.instance_variable_get('@source_file')))).must_equal false
        end
        AIPP.options.clean = false
      end

      it "downloads XML documents to Nokogiri::XML::Document" do
        URI.stub(:open, File.open(fixtures_path.join('downloader', 'new.xml'))) do
          AIPP::Downloader.new(storage: tmp_dir, source: 'source') do |downloader|
            downloader.read(document: 'new', url: 'http://localhost/new.xml').tap do |content|
              _(content).must_be_instance_of Nokogiri::XML::Document
              _(content.css('element').text).must_equal 'fixture-xml-new'
            end
          end
        end
      end

      it "downloads HTML documents to Nokogiri::HTML5::Document" do
        URI.stub(:open, File.open(fixtures_path.join('downloader', 'new.html'))) do
          AIPP::Downloader.new(storage: tmp_dir, source: 'source') do |downloader|
            downloader.read(document: 'new', url: 'http://localhost/new.html').tap do |content|
              _(content).must_be_instance_of Nokogiri::HTML5::Document
              _(content.text).must_match(/fixture-html-new/)
            end
          end
        end
      end

      it "downloads PDF documents to AIPP::PDF" do
        URI.stub(:open, File.open(fixtures_path.join('downloader', 'new.pdf'))) do
          AIPP::Downloader.new(storage: tmp_dir, source: 'source') do |downloader|
            downloader.read(document: 'new', url: 'http://localhost/new.pdf').tap do |content|
              _(content).must_be_instance_of AIPP::PDF
              _(content.text).must_equal 'fixture-pdf-new'
            end
          end
        end
      end

      it "downloads XLSX documents to Roo::Excelx" do
        URI.stub(:open, File.open(fixtures_path.join('downloader', 'new.xlsx'))) do
          AIPP::Downloader.new(storage: tmp_dir, source: 'source') do |downloader|
            downloader.read(document: 'new', url: 'http://localhost/new.xlsx').tap do |content|
              _(content).must_be_instance_of Roo::Excelx
              _(content.sheet(0).cell(1, 1)).must_equal 'fixture-xlsx-new'
            end
          end
        end
      end

      it "downloads ODS documents to Roo::OpenOffice" do
        URI.stub(:open, File.open(fixtures_path.join('downloader', 'new.ods'))) do
          AIPP::Downloader.new(storage: tmp_dir, source: 'source') do |downloader|
            downloader.read(document: 'new', url: 'http://localhost/new.ods').tap do |content|
              _(content).must_be_instance_of Roo::OpenOffice
              _(content.sheet(0).cell(1, 1)).must_equal 'fixture-ods-new'
            end
          end
        end
      end

      it "downloads CSV documents to Roo::CSV" do
        URI.stub(:open, File.open(fixtures_path.join('downloader', 'new.csv'))) do
          AIPP::Downloader.new(storage: tmp_dir, source: 'source') do |downloader|
            downloader.read(document: 'new', url: 'http://localhost/new.csv').tap do |content|
              _(content).must_be_instance_of Roo::CSV
              _(content.sheet(0).cell(1, 1)).must_equal 'fixture-csv-new'
            end
          end
        end
      end

      it "downloads TXT documents to String" do
        URI.stub(:open, File.open(fixtures_path.join('downloader', 'new.txt'))) do
          AIPP::Downloader.new(storage: tmp_dir, source: 'source') do |downloader|
            downloader.read(document: 'new', url: 'http:/localhost/new.txt').tap do |content|
              _(content).must_be_instance_of String
              _(content.split.first).must_equal 'fixture-txt-new'
            end
          end
        end
      end

      context "SQL query" do
        it "downloads PostgreSQL SELECT query to Nokogiri::XML::Document" do
          PG::Connection.stub(:sync_connect, nil, db) do
            AIPP::Downloader.new(storage: tmp_dir, source: 'source') do |downloader|
              downloader.read(document: 'new', url: 'postgresql://localhost/db?command=SELECT+*+FROM+test').tap do |content|
                _(content).must_be_instance_of Nokogiri::XML::Document
                _(content.css('row:first column:first').text).must_equal 'fixture-sql-new'
              end
            end
          end
        end

        it "downloads MySQL SELECT query to Nokogiri::XML::Document" do
          Mysql.stub(:connect, db) do
            AIPP::Downloader.new(storage: tmp_dir, source: 'source') do |downloader|
              downloader.read(document: 'new', url: 'mysql://localhost/db?command=SELECT+*+FROM+test').tap do |content|
                _(content).must_be_instance_of Nokogiri::XML::Document
                _(content.css('row:first column:first').text).must_equal 'fixture-sql-new'
              end
            end
          end
        end
      end

      it "downloads explicitly specified type" do
        URI.stub(:open, File.open(fixtures_path.join('downloader', 'new.pdf'))) do
          AIPP::Downloader.new(storage: tmp_dir, source: 'source') do |downloader|
            downloader.read(document: 'new', url: 'http://localhost/new', type: :pdf).tap do |content|
              _(content).must_be_instance_of AIPP::PDF
              _(content.text).must_match(/fixture-pdf-new/)
            end
          end
        end
      end
    end
  end

  def zip_entries(zip_file)
    Zip::File.open(zip_file).entries.map(&:name).sort
  end

  def db
    Class.new do
      def exec(_)
        yield [{ first: 'fixture-sql-new', second: 'two', third: 'three' }, { first: 'uno', second: 'dos', third: 'tres' }]
      end

      def query(_)
        [{ first: 'fixture-sql-new', second: 'two', third: 'three' }, { first: 'uno', second: 'dos', third: 'tres' }].tap do |array|
          array.instance_eval { alias each_hash each }
        end
      end
    end.new
  end
end
