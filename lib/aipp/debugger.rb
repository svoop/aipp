module AIPP
  module Debugger

    # Start a debugger session and watch for warnings etc
    #
    # @note The debugger session persists beyond the scope of the given block
    #   because there's no +DEBUGGER__.stop+ as of now.
    #
    # @example
    #   include AIPP::Debugger
    #   with_debugger(verbose: true) do
    #     (...)
    #     warn("all hell broke loose", severe: true)
    #   end
    #
    # @overload with_debugger(debug_on_warning:, debug_on_error:, verbose:, &block)
    #   @param debug_on_warning [Boolean, Integer] start a debugger session
    #     which opens a console on the warning with the given integer ID or on
    #     all warnings if +true+ is given
    #   @param debug_on_error [Boolean] start a debugger session which opens
    #     a console when an error is raised (postmortem)
    #   @param verbose [Boolean] print verbose info, print unsevere warnings
    #     and re-raise rescued errors
    #   @yield Block the debugger is watching
    def with_debugger(**options, &)
      DEBUGGER__.instance_variable_set(:@options__, options.merge(counter: 0))
      case
      when id = debugger_options[:debug_on_warning]
        puts instructions_for(@id == true ? 'warning' : "warning #{id}")
        DEBUGGER__::start(no_sigint_hook: true, nonstop: true)
        call_with_rescue(&)
      when debugger_options[:debug_on_error]
        puts instructions_for('error')
        DEBUGGER__::start(no_sigint_hook: true, nonstop: true, postmortem: true)
        call_without_rescue(&)
      else
        DEBUGGER__::start(no_sigint_hook: true, nonstop: true)
        call_with_rescue(&)
      end
    end

    def self.included(*)
      DEBUGGER__.instance_variable_set(:@options__, {})
    end

    # Issue a warning and maybe open a debug session.
    #
    # @param message [String] warning message
    # @param severe [Boolean] whether this problem must be fixed or not
    alias_method :original_warn, :warn
    def warn(message, severe: true)
      if severe || debugger_options[:verbose]
        debugger_options[:counter] += 1
        original_warn "WARNING #{debugger_options[:counter]}: #{message.upcase_first} #{'(unsevere)' unless severe}".red
        debugger if debugger_options[:debug_on_warning] == true || debugger_options[:debug_on_warning] == debugger_options[:counter]
      end
    end

    # Issue an informational message.
    #
    # @param message [String] informational message
    # @param color [Symbol] message color
    def info(message, color: nil)
      puts color ? message.upcase_first.send(color) : message.upcase_first
    end

    # Issue a verbose informational message.
    #
    # @param message [String] verbose informational message
    # @param color [Symbol] message color
    def verbose_info(message, color: :blue)
      info(message, color: color) if debugger_options[:verbose]
    end

    private

    def debugger_options
      DEBUGGER__.instance_variable_get(:@options__)
    end

    def call_with_rescue(&block)
      block.call
    rescue => error
      message = error.respond_to?(:original_message) ? error.original_message : error.message
      puts "ERROR: #{message}".magenta
      raise if debugger_options[:verbose]
    end

    def call_without_rescue(&block)
      block.call
    end

    def instructions_for(trigger)
      <<~END.strip.red
        Debug on #{trigger} enabled.
        Remember: Type "up" to enter caller frames.
      END
    end

  end
end
