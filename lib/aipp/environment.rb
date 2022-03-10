module AIPP

  # Runtime environment
  #
  # Runtime environment objects inherit from OpenStruct but feature some
  # extensions:
  #
  # * Use +replace+ to replace the current key/value table with the given hash.
  # * Use +merge+ to merge the given hash into the current key/value hash.
  # * When reading a value using square brackets, the key is implicitly
  #   converted to Symbol.
  #
  # @example
  #   AIPP.config                      # => AIPP::Environment::Config
  #   AIPP.config.foo                  # => nil
  #   AIPP.config.foo = :bar           # => :bar
  #   AIPP.config.replace(fii: :bir)
  #   AIPP.config.foo                  # => nil
  #   AIPP.config.fii                  # => :bir
  #   AIPP.config.read!                # method defined on Config class
  class Environment
    include Singleton

    # Cache to store transient objects
    class Cache < OpenStruct
      def [](key)
        super(key.to_s.to_sym)
      end

      def replace(hash)
        @table = hash
      end

      def merge(hash)
        @table.merge! hash
      end
    end

    # Borders read from directory containing GeoJSON files
    class Borders < Cache
      def read!(dir)
        @table.clear
        dir.glob('*.geojson').each do |file|
          @table[file.basename('.geojson').to_s.to_sym] = AIPP::Border.from_file(file)
        end
      end
    end

    # Fixtures read from directory containing YAML files
    class Fixtures < Cache
      def read!(dir)
        @table.clear
        dir.glob('*.yml').each do |file|
          @table[file.basename('.yml').to_s.to_sym] = YAML.load_file(file)
        end
      end
    end

    # Options set via the CLI executable
    class Options < Cache
    end

    # Config read from config.yml file
    class Config < Cache
      def read!(file)
        @table = YAML.safe_load_file(file, symbolize_names: true, fallback: {}) if file.exist?
        @table[:namespace] ||= SecureRandom.uuid
      end

      def write!(file)
        File.write(file, @table.transform_keys(&:to_s).to_yaml)
      end
    end

    def initialize
      [Cache, Borders, Fixtures, Options, Config].each do |klass|
        attribute = klass.to_s.split('::').last.downcase
        instance_variable_set("@#{attribute}", klass.new)
        AIPP.define_singleton_method(attribute) do
          Environment.instance.instance_variable_get "@#{attribute}"
        end
      end
    end

  end
end

AIPP::Environment.instance
