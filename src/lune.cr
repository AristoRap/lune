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
require "./lune/bus/events"
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
  VERSION = "0.12.0"

  # Module-level registration so third-party shards can publish plugins the
  # same way built-ins do: `Lune.use(MyPlugin.new)` before `Lune.run`. The
  # built-ins themselves call `Lune.use` from `src/lune/plugins/builtins.cr`
  # at require time, so by the time user code runs the array already holds
  # them. `Plugins::Registry` consumes this array — no hardcoded list.
  @@registered_plugins = [] of Lune::Plugin
  @@registered_ids = Set(Symbol).new

  def self.use(plugin : Lune::Plugin) : Nil
    id = plugin.descriptor.id
    if @@registered_ids.includes?(id)
      raise ArgumentError.new("Plugin #{id.inspect} already registered (descriptor IDs must be unique)")
    end
    @@registered_ids << id
    @@registered_plugins << plugin
  end

  def self.registered_plugins : Array(Lune::Plugin)
    @@registered_plugins
  end

  def self.clear_registered_plugins! : Nil
    @@registered_plugins.clear
    @@registered_ids.clear
  end

  # Snapshot the current registration set, replace it with `plugins` for the
  # duration of the block, then restore. Spec helper — production code never
  # needs this. Always restores in `ensure`, including on exceptions.
  def self.with_plugins(*plugins : Lune::Plugin, &)
    saved = @@registered_plugins.dup
    saved_ids = @@registered_ids.dup
    @@registered_plugins.clear
    @@registered_ids.clear
    plugins.each { |p| use(p) }
    begin
      yield
    ensure
      @@registered_plugins = saved
      @@registered_ids = saved_ids
    end
  end

  # Default frontend directory name (matches the lune.yml default).
  DEFAULT_FRONTEND_DIR = "frontend"

  # Subdirectory under frontend.dir where Lune writes its generated JS/TS files.
  LUNEJS_SUBDIR = "lunejs"

  # Environment variables written by the CLI and read by the compiled app.
  ENV_DEV_URL      = "LUNE_DEV_URL"
  ENV_FRONTEND_DIR = "LUNE_FRONTEND_DIR"

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

    {% if flag?(:build_mode) %}
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
end
