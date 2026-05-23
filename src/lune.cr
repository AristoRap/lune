require "./lune/assets/server"
require "./lune/assets/store"
require "./lune/config"
require "./lune/options/registry"
require "./lune/logger"
require "./lune/binding"
require "./lune/native/**"
require "./lune/webview"
require "./lune/error"
require "./lune/bridge"
require "./lune/mixins/installable"
require "./lune/mixins/subscribable"
require "./lune/bus/event"
require "./lune/bus/stream"
require "./lune/plugin"
require "./lune/mixins/bindable"
require "./lune/plugins/*"
require "./lune/plugins/builtins"
require "./lune/generator"
require "./lune/app"
require "./lune/platform/window_state"
require "./lune/platform/single_instance"
require "./lune/platform/deep_link_ipc"
require "./lune/runner"

module Lune
  VERSION = "0.14.0"

  # Module-level registration so third-party shards can publish plugins the
  # same way built-ins do: `Lune.use(MyPlugin.new)` before `Lune.run`. The
  # built-ins themselves call `Lune.use` from `src/lune/plugins/builtins.cr`
  # at require time, so by the time user code runs the array already holds
  # them. `Plugins::Registry` consumes this array — no hardcoded list.
  @@registered_plugins = [] of Lune::Plugin
  @@registered_ids = Set(Symbol).new
  @@registered_accessors = {} of Symbol => Symbol # opts accessor → descriptor.id of the plugin holding it

  # Classes blessed to live in the reserved `Lune::Plugins::` namespace.
  # Populated by `Lune::Plugins.register_builtins!` before each `Lune.use` call.
  # `Lune.use` checks this set to catch third-party shards that squat on the
  # framework namespace — class reopens (monkey-patching an existing built-in)
  # still get through because the registered class IS the built-in, but that
  # requires deliberately re-declaring the framework class and is a
  # don't-do-that signal we don't try to police at runtime.
  @@blessed_builtins = Set(String).new

  # Marks a class name as an allowed inhabitant of `Lune::Plugins::`. Called
  # from `register_builtins!` for every built-in at module load. Not for
  # third-party use — third-party plugins live in their own namespace.
  def self._bless_builtin(klass_name : String) : Nil
    @@blessed_builtins << klass_name
  end

  # Register one or more plugins. Splat shape mirrors `App#install(*mods)` so
  # callers can group several lines into one — `Lune.use(A.new, B.new, C.new)`.
  # Uniqueness is checked per plugin on two axes:
  #   1. `descriptor.id` — the `lune.yml` / soft-dep / sentinel key.
  #   2. `lune_options_accessor` (set by the `config` macro) — the `opts.<name>`
  #      method the plugin grafts onto `Lune::Options`. Two plugins claiming
  #      the same accessor would silently fight at compile time (Crystal lets
  #      the second `def` win); catching it here surfaces the conflict at
  #      registration with a fix the user can act on (pass an explicit name
  #      to `config(:my_name)`).
  # The registry is append-only — earlier plugins in the same call remain
  # registered, so partial registration is fine.
  def self.use(*plugins : Lune::Plugin) : Nil
    plugins.each do |plugin|
      id = plugin.descriptor.id
      klass_name = plugin.class.name

      if klass_name.starts_with?("Lune::Plugins::") && !@@blessed_builtins.includes?(klass_name)
        raise RegistrationError.new(
          "Plugin class `#{klass_name}` lives in the `Lune::Plugins::` namespace, which is reserved for built-in plugins",
          hint: "Move your plugin under your own top-level namespace, e.g. `MyShard::MyPlugin`."
        )
      end

      if @@registered_ids.includes?(id)
        raise RegistrationError.new(
          "Plugin #{id.inspect} already registered",
          hint: "Descriptor ids must be unique across built-ins and third-party plugins."
        )
      end
      if accessor = plugin.lune_options_accessor
        if previous_id = @@registered_accessors[accessor]?
          raise RegistrationError.new(
            "Plugin #{id.inspect} claims opts accessor `#{accessor}`, already taken by #{previous_id.inspect}",
            hint: "Pass an explicit name to the macro: `config(:my_unique_name) do …`."
          )
        end
        @@registered_accessors[accessor] = id
      end
      @@registered_ids << id
      @@registered_plugins << plugin
    end
  end

  def self.registered_plugins : Array(Lune::Plugin)
    @@registered_plugins
  end

  # Direct read access for spec helpers that need to snapshot / restore the
  # registration set. Not part of the public API — production code uses
  # `Lune.use` (write) and `Lune.registered_plugins` (read) and nothing else.
  protected def self.registered_ids : Set(Symbol)
    @@registered_ids
  end

  protected def self.registered_accessors : Hash(Symbol, Symbol)
    @@registered_accessors
  end

  protected def self.replace_registration!(
    plugins : Array(Lune::Plugin),
    ids : Set(Symbol),
    accessors : Hash(Symbol, Symbol) = {} of Symbol => Symbol,
  ) : Nil
    @@registered_plugins = plugins
    @@registered_ids = ids
    @@registered_accessors = accessors
  end

  # TsType registry: structs / records / classes annotated with
  # `@[Lune::TsType]` and referenced by a `@[Lune::Bind]` return type land here
  # via the `Bindable` macro. `Lune::Generator.generate_runtime_dts` reads from
  # this hash and emits one `export interface <Name> { ... }` per entry at the
  # top of `runtime.d.ts`, so plugin authors can hand the frontend named types
  # instead of inlined anonymous shapes. Field types are stored as raw Crystal
  # strings (`"Int32"`, `"Array(String)"`, …) and rendered via `crystal_to_ts`
  # at emit time — keeps the registry purely structural and lets the same TS
  # mapping rules apply uniformly to fields and binding signatures.
  @@registered_ts_types = {} of String => Array(Tuple(String, String))

  def self.register_ts_type(name : String, fields : Array(Tuple(String, String))) : Nil
    @@registered_ts_types[name] = fields
  end

  def self.registered_ts_types : Hash(String, Array(Tuple(String, String)))
    @@registered_ts_types
  end

  # Default frontend directory name (matches the lune.yml default).
  DEFAULT_FRONTEND_DIR = "frontend"

  # Subdirectory under frontend.dir where Lune writes its generated JS/TS files.
  LUNEJS_SUBDIR = "lunejs"

  # Environment variables written by the CLI and read by the compiled app.
  ENV_DEV_URL      = "LUNE_DEV_URL"
  ENV_FRONTEND_DIR = "LUNE_FRONTEND_DIR"
  ENV_APP_NAME     = "LUNE_APP_NAME"

  # Display name for the running app, baked at compile time from `lune.yml`'s
  # `name:` (forwarded by the CLI via `LUNE_APP_NAME`). Falls back to "Lune"
  # when the binary is built outside the CLI or `name:` is unset. Win32 uses
  # it to derive the toast-notification AUMID; other platforms may pick it up
  # for window titles / log prefixes as needed.
  APP_NAME = {{ env("LUNE_APP_NAME") || "Lune" }}

  # Navigation priority (first match wins):
  #   1. html:   — inline HTML string (useful for tests and simple apps)
  #   2. url:    — explicit URL
  #   3. LUNE_DEV_URL env var — Vite dev server (set automatically by the CLI)
  #   4. assets: — directory embedded at compile time, served locally in prod
  #

  macro run(app, **options, &block)
    {% if options[:assets] %}
      ::Lune::Assets.embed_dir({{ options[:assets] }})
    {% end %}

    {% if flag?(:lune_inspect) %}
      ::Lune._inspect_run
    {% elsif flag?(:build_mode) %}
      ::Lune._build_run({{ app }})
    {% else %}
      runner = ::Lune::Runner.new({{ app }}) do |opts|
        {% if block %}
          {{ block.body }}
        {% end %}
      end
      runner.start
    {% end %}
  end

  def self._build_run(app : App) : Nil
    logger.info { "Running in build mode" }
    lunejs_dir = File.join(ENV.fetch(ENV_FRONTEND_DIR, DEFAULT_FRONTEND_DIR), LUNEJS_SUBDIR)
    config = Config.load
    registry = Plugins::Registry.new(Pointer(Void).null, Options.new)
    stubs = App.new
    resolved = registry.validate_resolve_install(config.plugins, stubs)
    Generator.write_js(
      app.bindings + stubs.bindings.select(&.internal?),
      lunejs_dir,
      resolved.plugins,
      registry.platform_filtered,
    )
  end

  # `-Dlune_inspect` short-circuits `Lune.run` before the runner starts and
  # before `_build_run` writes any artifacts. Prints the registered set to
  # stdout in a stable, machine-readable shape (one tab-separated row per
  # plugin: `id<tab>label<tab>platforms<tab>built_in`, framed by
  # `<<<LUNE_PLUGINS` / `LUNE_PLUGINS>>>`) for `lune doctor --plugins` to
  # parse. Everything that runs before `Lune.run` — `require`s, `Lune.use`
  # calls, top-level constants — has already executed by the time we get
  # here, so the list is what the live app would see.
  def self._inspect_run : Nil
    STDOUT.puts "<<<LUNE_PLUGINS"
    registered_plugins.each do |p|
      d = p.descriptor
      STDOUT.puts "#{d.id}\t#{d.label}\t#{d.platforms.join(",")}\t#{p.built_in?}"
    end
    STDOUT.puts "LUNE_PLUGINS>>>"
    exit 0
  end
end
