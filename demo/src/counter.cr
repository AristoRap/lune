require "lune"

# Demo of a user-defined plugin. Subclasses `Lune::Plugin`, declares a
# `config do … end` block (so `opts.counter.step = …` works), exposes a
# handful of `@[Lune::Bind]` methods to JS, and emits an event on every
# change so the frontend can react.
#
# Wired in from `demo/src/main.cr` with `Lune.use(Counter.new)`. From JS,
# the plugin is a top-level export — `import { Counter } from "../lune.js"`
# (third-party plugins don't live under the `lune.*` alias, that one's
# reserved for first-party `Lune::Plugins::*`).
module MyCustomPlugin
  class Counter < Lune::Plugin
    include Lune::Bindable
    include Lune::Plugin::Lifecycle

    DESCRIPTOR = Descriptor.new(
      id: :counter,
      label: "Counter",
      soft_deps: [:event], # emits change events when the bus is around
    )

    def descriptor : Descriptor
      DESCRIPTOR
    end

    config do
      # Starting value, applied lazily on first access if `reset` has never
      # been called. Setting this in `Lune.run` seeds the counter at boot.
      property start_at : Int32 = 0

      # Amount each `increment` / `decrement` call moves the value by.
      property step : Int32 = 1
    end

    @value : Int32 = 0
    @seeded = false

    def setup(ctx : SetupCtx) : Nil
      @value = @config.start_at
      @seeded = true
    end

    @[Lune::Bind]
    def value : Int32
      @value
    end

    @[Lune::Bind]
    def increment : Int32
      @value += @config.step
      emit_changed
      @value
    end

    @[Lune::Bind]
    def decrement : Int32
      @value -= @config.step
      emit_changed
      @value
    end

    @[Lune::Bind]
    def reset : Int32
      @value = @config.start_at
      emit_changed
      @value
    end

    def shutdown : Nil
      Lune.logger.info { "Counter shutting down — final value=#{@value}" }
    end

    private def emit_changed : Nil
      @app.event.emit("counter:changed", {"value" => @value})
    end
  end
end
