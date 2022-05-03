require_relative '../../../spec_helper'

describe AIPP::Downloader::File do
  subject do
    AIPP::Downloader::File
  end

  describe :name do
    it "isolates the name" do
      _(subject.new(file: 'path/to/foobar.txt').send(:name)).must_equal 'foobar'
    end
  end

  describe :type do
    it "isolates the type" do
      _(subject.new(file: 'path/to/foobar.txt').send(:type)).must_equal 'txt'
    end

    it "gives precedence to the declared type" do
      _(subject.new(file: 'path/to/foobar.txt', type: 'pdf').send(:type)).must_equal 'pdf'
    end
  end

  describe :fetch_to do
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
        downloader = AIPP::Downloader::File.new(file: subject).fetch_to(tmp_dir)
        _(downloader.fetched_file).must_equal 'new.txt'
        _(tmp_dir.join('new.txt')).path_must_exist
      end

      it "fetches the file and overrides the type" do
        downloader = AIPP::Downloader::File.new(file: subject, type: :csv).fetch_to(tmp_dir)
        _(downloader.fetched_file).must_equal 'new.csv'
        _(tmp_dir.join('new.csv')).path_must_exist
      end

      it "fails if file doesn't exist" do
        downloader = AIPP::Downloader::File.new(file: 'missing.txt')
        _{ downloader.fetch_to(tmp_dir) }.must_raise AIPP::Downloader::NotFoundError
      end
    end

    context 'ZIP archive' do
      subject do
        fixtures_path.join('downloader', 'archive.zip')
      end

      it "extracts the file and detects the type" do
        downloader = AIPP::Downloader::File.new(archive: subject, file: 'archive/new.txt').fetch_to(tmp_dir)
        _(downloader.fetched_file).must_equal 'new.txt'
        _(tmp_dir.join('new.txt')).path_must_exist
      end

      it "extracts the file and overrides the type" do
        downloader = AIPP::Downloader::File.new(archive: subject, file: 'archive/new.txt', type: :csv).fetch_to(tmp_dir)
        _(downloader.fetched_file).must_equal 'new.csv'
        _(tmp_dir.join('new.csv')).path_must_exist
      end

      it "fails if archive doesn't exist" do
        downloader = AIPP::Downloader::File.new(archive: 'missing.zip', file: 'archive/new.txt')
        _{ downloader.fetch_to(tmp_dir) }.must_raise AIPP::Downloader::NotFoundError
      end

      it "fails if file doesn't exist in archive" do
        downloader = AIPP::Downloader::File.new(archive: subject, file: 'archive/missing.txt')
        _{ downloader.fetch_to(tmp_dir) }.must_raise AIPP::Downloader::NotFoundError
      end
    end
  end
end
