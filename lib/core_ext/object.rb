class Object

  # Issue a warning and maybe open a Pry session attached to the error or
  # binding passed.
  #
  # @example with error context
  #   begin
  #     (...)
  #   rescue => error
  #     warn("oops", pry: error)
  #   end
  # @example with binding context
  #   warn("oops", pry: binding)
  # @param message [String] warning message
  # @param pry [Exception, Binding, nil] attach the Pry session to this error
  #   or binding
  def warn(message, pry:)
    $WARN_COUNTER = $WARN_COUNTER.to_i + 1
    Kernel.warn "WARNING #{$WARN_COUNTER}: #{message}".red
    if $PRY_ON_WARN == true || $PRY_ON_WARN == $WARN_COUNTER
      case pry
        when Exception then Pry::rescued(pry)
        when Binding then pry.pry
      end
    end
  end

  # Issue an informational message.
  #
  # @param message [String] informational message
  def info(message, color: :black)
    puts message.send(color)
  end

  # Issue a patch message.
  #
  # @param message [String] patch message
  def patch(message)
    info("PATCH: #{message}", color: :magenta)
  end

  # Issue a debug message.
  #
  # @param message [String] debug message
  def debug(message)
    info(message, color: :blue) if $DEBUG
  end

end
