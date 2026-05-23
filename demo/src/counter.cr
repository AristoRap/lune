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
  # `@[Lune::TsType]` marks a Crystal struct as a TypeScript surface type.
  # The Lune generator picks it up via the `Bindable` macro the moment any
  # `@[Lune::Bind]` method returns this struct, and emits a matching
  # `export interface CounterState { ... }` into `runtime.d.ts`. Frontend
  # code can `import type { CounterState } from "../lunejs/runtime/runtime.js"`
  # and get a real name on the wire shape instead of an anonymous object
  # literal. Field types flow through the same `crystal_to_ts` mapping as
  # binding signatures, so generics and primitives stay in sync.
  @[Lune::TsType]
  struct CounterState
    include JSON::Serializable
    getter value : Int32
    getter step : Int32
    getter at_default : Bool

    def initialize(@value, @step, @at_default)
    end
  end

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

    # Returns the full counter state as a TsType-annotated struct. The JS
    # signature is `Counter.state(): Promise<CounterState>` — a named
    # interface, not an anonymous shape.
    @[Lune::Bind]
    def state : CounterState
      CounterState.new(@value, @config.step, @value == @config.start_at)
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
