require_relative '../../spec_helper'

describe AIPP::Downloader do
  let :fixtures_dir do
    Pathname(__FILE__).join('..', '..', '..', 'fixtures')
  end

  let :tmp_dir do
    Pathname(Dir.mktmpdir).tap do |tmp_dir|
      (archives_dir = tmp_dir.join('archives')).mkpath
      FileUtils.cp(fixtures_dir.join('archive.zip'), archives_dir)
    end
  end

  after do
    FileUtils.rm_rf(tmp_dir)
  end

  describe :read do
    context "archive does not exist" do
      it "creates the archive" do
        Spy.on(Kernel, open: File.open(fixtures_dir.join('new.html')))
        subject = AIPP::Downloader.new(storage: tmp_dir, archive: 'new-archive') do |downloader|
          File.exist?(tmp_dir.join('work')).must_equal true
          downloader.read(document: 'new', url: 'http://localhost/new.html')
        end
        zip_entries(subject.archive_file).must_equal %w(new.html)
        subject.send(:archives_path).children.count.must_equal 2
      end
    end

    context "archive does exist" do
      it "unzips and uses the archive" do
        Spy.on(Kernel, open: File.open(fixtures_dir.join('new.html')))
        subject = AIPP::Downloader.new(storage: tmp_dir, archive: 'archive') do |downloader|
          File.exist?(tmp_dir.join('work')).must_equal true
          downloader.read(document: 'new', url: 'http://localhost/new.html').tap do |content|
            content.must_be_instance_of Nokogiri::HTML5::Document
            content.text.must_match /fixture-html-new/
          end
        end
        zip_entries(subject.archive_file).must_equal %w(new.html one.html two.html)
        subject.send(:archives_path).children.count.must_equal 1
      end

      it "downloads HTML documents to Nokogiri" do
        Spy.on(Kernel, open: File.open(fixtures_dir.join('new.html')))
        AIPP::Downloader.new(storage: tmp_dir, archive: 'archive') do |downloader|
          downloader.read(document: 'new', url: 'http://localhost/new.html').tap do |content|
            content.must_be_instance_of Nokogiri::HTML5::Document
            content.text.must_match /fixture-html-new/
          end
        end
      end

      it "downloads and caches PDF documents to String" do
        Spy.on(Kernel, open: File.open(fixtures_dir.join('new.pdf')))
        AIPP::Downloader.new(storage: tmp_dir, archive: 'archive') do |downloader|
          downloader.read(document: 'new', url: 'http://localhost/new.pdf').tap do |content|
            content.must_be_instance_of String
            content.must_match /fixture-pdf-new/
          end
          downloader.send(:work_path).join('new.txt').must_be :exist?
        end
      end

      it "downloads TXT documents to String" do
        Spy.on(Kernel, open: File.open(fixtures_dir.join('new.txt')))
        AIPP::Downloader.new(storage: tmp_dir, archive: 'archive') do |downloader|
          downloader.read(document: 'new', url: 'http://localhost/new.txt').tap do |content|
            content.must_be_instance_of String
            content.must_match /fixture-txt-new/
          end
        end
      end

      it "downloads explicitly specified type" do
        Spy.on(Kernel, open: File.open(fixtures_dir.join('new.pdf')))
        AIPP::Downloader.new(storage: tmp_dir, archive: 'archive') do |downloader|
          downloader.read(document: 'new', url: 'http://localhost/new', type: :pdf).tap do |content|
            content.must_be_instance_of String
            content.must_match /fixture-pdf-new/
          end
        end
      end
    end
  end

  def zip_entries(zip_file)
    Zip::File.open(zip_file).entries.map(&:name).sort
  end
end
