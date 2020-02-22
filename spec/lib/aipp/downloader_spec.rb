require_relative '../../spec_helper'

describe AIPP::Downloader do
  let :fixtures_dir do
    Pathname(__FILE__).join('..', '..', '..', 'fixtures')
  end

  let :tmp_dir do
    Pathname(Dir.mktmpdir).tap do |tmp_dir|
      (sources_dir = tmp_dir.join('sources')).mkpath
      FileUtils.cp(fixtures_dir.join('source.zip'), sources_dir)
    end
  end

  after do
    FileUtils.rm_rf(tmp_dir)
  end

  describe :read do
    context "source archive does not exist" do
      it "creates the source archive" do
        Spy.on(URI, open: File.open(fixtures_dir.join('new.html')))
        subject = AIPP::Downloader.new(storage: tmp_dir, source: 'new-source') do |downloader|
          _(File.exist?(tmp_dir.join('work'))).must_equal true
          downloader.read(document: 'new', url: 'http://localhost/new.html')
        end
        _(zip_entries(subject.source_file)).must_equal %w(new.html)
        _(subject.send(:sources_path).children.count).must_equal 2
      end
    end

    context "source archive does exist" do
      it "unzips and uses the source archive" do
        Spy.on(URI, open: File.open(fixtures_dir.join('new.html')))
        subject = AIPP::Downloader.new(storage: tmp_dir, source: 'source') do |downloader|
          _(File.exist?(tmp_dir.join('work'))).must_equal true
          downloader.read(document: 'new', url: 'http://localhost/new.html').tap do |content|
            _(content).must_be_instance_of Nokogiri::HTML5::Document
            _(content.text).must_match /fixture-html-new/
          end
        end
        _(zip_entries(subject.source_file)).must_equal %w(new.html one.html two.html)
        _(subject.send(:sources_path).children.count).must_equal 1
      end

      it "downloads HTML documents to Nokogiri::HTML5::Document" do
        Spy.on(URI, open: File.open(fixtures_dir.join('new.html')))
        AIPP::Downloader.new(storage: tmp_dir, source: 'source') do |downloader|
          downloader.read(document: 'new', url: 'http://localhost/new.html').tap do |content|
            _(content).must_be_instance_of Nokogiri::HTML5::Document
            _(content.text).must_match /fixture-html-new/
          end
        end
      end

      it "downloads and caches PDF documents to AIPP::PDF" do
        Spy.on(URI, open: File.open(fixtures_dir.join('new.pdf')))
        AIPP::Downloader.new(storage: tmp_dir, source: 'source') do |downloader|
          downloader.read(document: 'new', url: 'http://localhost/new.pdf').tap do |content|
            _(content).must_be_instance_of AIPP::PDF
            _(content.text).must_match /fixture-pdf-new/
          end
        end
      end

      it "downloads explicitly specified type" do
        Spy.on(URI, open: File.open(fixtures_dir.join('new.pdf')))
        AIPP::Downloader.new(storage: tmp_dir, source: 'source') do |downloader|
          downloader.read(document: 'new', url: 'http://localhost/new', type: :pdf).tap do |content|
            _(content).must_be_instance_of AIPP::PDF
            _(content.text).must_match /fixture-pdf-new/
          end
        end
      end
    end
  end

  def zip_entries(zip_file)
    Zip::File.open(zip_file).entries.map(&:name).sort
  end
end
