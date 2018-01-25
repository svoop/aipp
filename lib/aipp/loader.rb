module AIPP
  class Loader
    using AIPP::Refinements

    attr_accessor :aixm

    def self.parsers_path
      Pathname(__dir__).join('parsers')
    end

    def self.list
      parsers_path.each_child.each.with_object({}) do |fir, hash|
        hash[fir.basename.to_s] = fir.glob('*.rb').map do |aip|
          aip.basename('.rb').to_s
        end
      end
    end

    def initialize(fir:, aip:, airac:, limit:)
      @fir, @aip, @airac, @limit = fir.upcase, aip.upcase, airac, limit
      load_parser
      @aixm = AIXM.document(effective_at: @airac)
      convert!
      warn "WARNING: document is not complete" unless aixm.complete?
      warn aixm.errors.prepend("WARNING: document ist not valid:").join("\n") unless aixm.valid?
    rescue LoadError
      raise(LoadError, "no parser found for FIR `#{@fir}' and AIP `#{@aip}'")
    end

    private

    def load_parser
      self.class.parsers_path.join(@fir, 'helpers').glob('*.rb').each do |helper|
        require helper
      end
      require_relative "parsers/#{@fir}/#{@aip}"
      self.singleton_class.send(:include, AIPP::Parsers)
    end

    def file
      file_name = "#{@fir}_#{@aip}_#{@airac}.html"
      Pathname.new(Dir.tmpdir).join(file_name).tap do |file_path|
        IO.copy_stream(open(url), file_path) unless File.exist?(file_path)
      end
    end

    def html
      @html ||= Nokogiri::HTML5(file)
    end

  end
end
