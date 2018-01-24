module AIPP
  class Loader
    using AIPP::Refinements

    attr_accessor :aixm

    def self.list
      parser_path = Pathname(__dir__).join('parser')
      Dir.each_child(parser_path).each.with_object({}) do |fir, hash|
        hash[fir] = Dir.children(parser_path.join(fir)).map do |aip_file|
          File.basename(aip_file, '.rb')
        end
      end
    end

    def initialize(fir:, aip:, airac:, limit:)
      @fir, @aip, @airac, @limit = fir.upcase, aip.upcase, airac, limit
      require_relative "parser/#{@fir}/#{@aip}.rb"
      self.singleton_class.send(:include, AIPP::Parser)
      @aixm = AIXM.document(effective_at: @airac)
      convert!
      warn "WARNING: document is not complete" unless aixm.complete?
      warn aixm.errors.prepend("WARNING: document ist not valid:").join("\n") unless aixm.valid?
    rescue LoadError
      raise(LoadError, "no parser found for FIR `#{@fir}' and AIP `#{@aip}'")
    end

    private

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
