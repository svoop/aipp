require_relative '../../../spec_helper'

describe AIPP::Downloader::HTTP do
  subject do
    AIPP::Downloader::HTTP
  end

  describe :name do
    it "isolates the name" do
      _(subject.new(file: 'http://example.com/path/to/foobar.txt').send(:name)).must_equal 'foobar'
    end

    it "uses digest as name if none can be isolated" do
      _(subject.new(file: 'http://example.com').send(:name)).must_equal 'a9b9f043'
    end
  end

  describe :type do
    it "isolates the type" do
      _(subject.new(file: 'http://example.com/path/to/foobar.txt').send(:type)).must_equal 'txt'
    end

    it "gives precedence to the declared type" do
      _(subject.new(file: 'http://example.com/path/to/foobar.txt', type: :pdf).send(:type)).must_equal 'pdf'
    end
  end

  describe :fetch_to do
    before do
      unless Excon.defaults[:mock]
        Excon.defaults[:mock] = true
      end
    end

    let :tmp_dir do
      Pathname(Dir.mktmpdir)
    end

    after do
      FileUtils.rm_rf(tmp_dir)
    end

    context 'file' do
      subject do
        fixtures_path.join('downloader', 'new.txt')
      end

      it "fetches the file and detects the type" do
        Excon.stub({}, { headers: { 'Content-Type' => 'text/plain' }, body: subject.read, status: 200 })
        downloader = AIPP::Downloader::HTTP.new(file: 'http://example.com/path/new.txt').fetch_to(tmp_dir)
        _(downloader.fetched_file).must_equal 'new.txt'
        _(tmp_dir.join('new.txt')).path_must_exist
      end

      it "fetches the file and overrides the type" do
        Excon.stub({}, { headers: { 'Content-Type' => 'text/plain' }, body: subject.read, status: 200 })
        downloader = AIPP::Downloader::HTTP.new(file: 'http://example.com/path/new.txt', type: :csv).fetch_to(tmp_dir)
        _(downloader.fetched_file).must_equal 'new.csv'
        _(tmp_dir.join('new.csv')).path_must_exist
      end

      it "fails on 404 not found" do
        Excon.stub({}, { status: 404 })
        downloader = AIPP::Downloader::HTTP.new(file: 'http://example.com/path/new.txt')
        _{ downloader.fetch_to(tmp_dir) }.must_raise AIPP::Downloader::NotFoundError
      end
    end

    context 'ZIP archive' do
      subject do
        fixtures_path.join('downloader', 'archive.zip')
      end

      it "extracts the file and detects the type" do
        Excon.stub({}, { headers: { 'Content-Type' => 'application/zip' }, body: ::File.read(subject), status: 200 })
        downloader = AIPP::Downloader::HTTP.new(archive: 'http://example.com/path/archive.zip', file: 'archive/new.txt').fetch_to(tmp_dir)
        _(downloader.fetched_file).must_equal 'new.txt'
        _(tmp_dir.join('new.txt')).path_must_exist
      end

      it "extracts the file and overrides the type" do
        Excon.stub({}, { headers: { 'Content-Type' => 'application/zip' }, body: ::File.read(subject), status: 200 })
        downloader = AIPP::Downloader::HTTP.new(archive: 'http://example.com/path/archive.zip', file: 'archive/new.txt', type: :csv).fetch_to(tmp_dir)
        _(downloader.fetched_file).must_equal 'new.csv'
        _(tmp_dir.join('new.csv')).path_must_exist
      end

      it "fails on 404 not found" do
        Excon.stub({}, { status: 404 })
        downloader = AIPP::Downloader::HTTP.new(archive: 'http://example.com/path/archive.zip', file: 'archive/new.txt')
        _{ downloader.fetch_to(tmp_dir) }.must_raise AIPP::Downloader::NotFoundError
      end

      it "fails if file doesn't exist in archive" do
        Excon.stub({}, { headers: { 'Content-Type' => 'application/zip' }, body: ::File.read(subject), status: 200 })
        downloader = AIPP::Downloader::HTTP.new(archive: 'http://example.com/path/archive.zip', file: 'archive/missing.txt')
        _{ downloader.fetch_to(tmp_dir) }.must_raise AIPP::Downloader::NotFoundError
      end
    end
  end
end
