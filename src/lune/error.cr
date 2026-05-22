module Lune
  # Root of every exception the framework raises on its own.
  # Two-line print contract: a short `[CODE] message` header line, then an
  # optional indented `Fix: <hint>` block. `inspect_with_backtrace` swaps
  # Crystal's default `"<msg> (<ClassName>)\n<stack>"` for that contract so
  # unhandled framework errors at startup don't look like internal crashes.
  # Setting `LUNE_TRACE=1` restores the default behavior for debugging.
  #
  # The Bridge already reads `code` to forward typed errors to JS; every
  # subclass gets that for free. Plugins that need to surface a specific
  # JS-side code (e.g. `sqlite_not_open`) instantiate `Lune::Error` directly
  # with their own code rather than picking a subclass — the subclasses below
  # are reserved for framework-internal categories where there's a fixed
  # code per category.
  class Error < Exception
    getter code : String
    getter hint : String?

    def initialize(@code : String, message : String, @hint : String? = nil)
      super(message)
    end

    def inspect_with_backtrace(io : IO) : Nil
      if ENV["LUNE_TRACE"]?.try(&.in?("1", "true"))
        super
        return
      end
      io << '\n' << '[' << @code << "] " << message << '\n'
      if h = @hint
        io << '\n' << "  Fix: " << h << '\n'
      end
    end
  end

  # `Lune.use` rejected a plugin: duplicate descriptor id, duplicate `opts`
  # accessor, or third-party class squatting on the `Lune::Plugins::`
  # namespace. Caller-fixable — the message names the offending plugin and
  # the hint names the remediation.
  class RegistrationError < Error
    CODE = "PLUGIN_REGISTRATION"

    def initialize(message : String, hint : String? = nil)
      super(CODE, message, hint)
    end
  end

  # Setup-time misuse — `Lune.run` called without a navigation source,
  # `opts.<plugin>` referenced before the plugin was registered, etc.
  # Caught at startup, not at runtime per-call.
  class ConfigurationError < Error
    CODE = "CONFIGURATION"

    def initialize(message : String, hint : String? = nil)
      super(CODE, message, hint)
    end
  end

  # Raised by `App#eval` when called before the runner wires the bridge —
  # typically a plugin `install` hook or an `App#async` task racing the
  # bridge attach.
  class BridgeNotReadyError < Error
    CODE = "BRIDGE_NOT_READY"

    def initialize(message : String)
      super(CODE, message)
    end
  end
end
