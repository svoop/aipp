module AIPP
  module Progress

    # Issue an informational message.
    #
    # @param message [String] informational message
    # @param force [Boolean] whether to show the message only when in verbose mode
    # @param color [Symbol] override default color
    def info(message, force: false, color: nil)
      case
      when !force && options[:verbose]
        color ||= :blue
        puts message.send(color)
      when force
        color ||= :black
        puts message.send(color)
      end
    end

    # Issue a warning and maybe open a Pry session in the context of the error
    # or binding passed.
    #
    # @example with error context
    #   begin
    #     (...)
    #   rescue => error
    #     warn("oops", context: error)
    #   end
    # @example with binding context
    #   warn("oops", context: binding)
    # @param message [String] warning message
    # @param context [Exception, Binding, nil] error or binding object
    def warn(message, context: nil)
      $WARN_COUNTER = $WARN_COUNTER.to_i + 1
      Kernel.warn "WARNING #{$WARN_COUNTER}: #{message}".red
      Pry::rescued(context) if context && options[:pry_on_warn] == $WARN_COUNTER
    end

  end
end
