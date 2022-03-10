require_relative '../../spec_helper'

module WarningFilter
  ACCESSORS_RE = '(cache|borders|fixtures|options|config)'.freeze
  def warn(message, category: nil, **kwargs)
    return if /(method redefined; discarding old #{ACCESSORS_RE}|previous definition of #{ACCESSORS_RE} was here)/.match?(message)
    super
  end
end
Warning.extend WarningFilter

describe AIPP::Environment do
  before do
    Singleton.__init__(AIPP::Environment)
  end

  describe :cache do
    it "defaults to an empty OpenStruct" do
      _(AIPP.cache).must_equal OpenStruct.new
    end

    it "caches an object" do
      _(AIPP.cache.foo = :bar).must_equal :bar
      _(AIPP.cache.foo).must_equal :bar
      _(AIPP.cache.to_h.count).must_equal 1
    end

    describe :[] do
      it "converts the key to Symbol" do
        AIPP.cache.foo = :bar
        _(AIPP.cache[:foo]).must_equal :bar
        _(AIPP.cache['foo']).must_equal :bar
      end
    end

    describe :replace do
      it "replaces the table with the given hash" do
        AIPP.cache.replace(fii: :bir)
        _(AIPP.cache.fii).must_equal :bir
        _(AIPP.cache.to_h.count).must_equal 1
      end
    end

    describe :merge do
      it "merges the given hash into the table" do
        AIPP.cache.foo = :bar
        AIPP.cache.merge(fii: :bir)
        _(AIPP.cache.foo).must_equal :bar
        _(AIPP.cache.fii).must_equal :bir
        _(AIPP.cache.to_h.count).must_equal 2
      end
    end
  end

  describe :borders do
    describe :read! do
      it "reads GeoJSON files from directory" do
        _(AIPP.borders.to_h.count).must_equal 0
        AIPP.borders.read! fixtures_path.join('borders')
        _(AIPP.borders.to_h.count).must_equal 1
        _(AIPP.borders.oggystan).wont_be :nil?
      end
    end
  end

  describe :fixtures do
    describe :read! do
      it "reads YAML files from directory" do
        _(AIPP.fixtures.to_h.count).must_equal 0
        AIPP.fixtures.read! fixtures_path.join('fixtures')
        _(AIPP.fixtures.to_h.count).must_equal 1
        _(AIPP.fixtures.aerodromes).wont_be :nil?
      end
    end
  end

  describe :config do
    describe :read! do
      context "config.yml does exist" do
        it "reads config.yml" do
          AIPP.config.read! fixtures_path.join('config', 'config.yml')
          _(AIPP.config.namespace).must_equal '11111111-2222-3333-4444-555555555555'
          _(AIPP.config.foo).must_equal 'bar'
        end
      end

      context "config.yml does not exist" do
        it "sets random UUID namespace" do
          AIPP.config.read! fixtures_path.join('config', 'non-existant')
          _(AIPP.config.namespace).wont_equal '11111111-2222-3333-4444-555555555555'
          _(AIPP.config.namespace).must_match(/[\da-f]{8}-(?:[\da-f]{4}-){3}[\da-f]{12}/)
          _(AIPP.config.foo).must_be :nil?
        end
      end
    end

    describe :write! do
      it "writes config.yml" do
        Dir.mktmpdir do |tmpdir|
          source = fixtures_path.join('config', 'config.yml')
          target = Pathname(tmpdir).join('config.yml')
          AIPP.config.read! source
          AIPP.config.write! target
          _(FileUtils.identical?(source, target)).must_equal true
        end
      end
    end

  end
end
