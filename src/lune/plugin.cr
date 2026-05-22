module Lune
  abstract class Plugin
    include Lune::Installable

    # JS-side helper namespace (`window.__lune.on`, `window.__lune.crystalEmit`,
    # `window.__lune.stOn`, …). Bridge binding IDs no longer use this prefix —
    # they're plain `<Namespace>.<method>`, same for user and plugin bindings.
    BRIDGE_MARKER = "__lune"

    # Sentinel keys (`window["lune.plugins.<id>"] = true`) let JS feature-detect
    # which plugins are active in this build.
    SENTINEL_NS = "lune.plugins"

    # -------------------------------------------------------------------------
    # Descriptor — static self-description for each plugin.
    # Read by the registry before instantiation to build the dependency graph.
    # -------------------------------------------------------------------------
    record Descriptor,
      id : Symbol,
      label : String,
      deps : Array(Symbol) = [] of Symbol,                  # hard: auto-disabled if dep missing
      soft_deps : Array(Symbol) = [] of Symbol,             # optional: degrades gracefully
      core : Bool = false,                                  # true = cannot be excluded via config
      platforms : Array(Symbol) = [:darwin, :linux, :win32] # OSes where the plugin can run; filtered out elsewhere

    # -------------------------------------------------------------------------
    # Context structs — passed to each lifecycle phase instead of raw args.
    # -------------------------------------------------------------------------

    struct SetupCtx
      getter options : Options
      getter handle : Pointer(Void)
      getter on_quit : -> Nil

      def initialize(@options : Options, @handle : Pointer(Void), @on_quit : -> Nil = -> { })
      end
    end

    struct WebviewCtx
      getter wv : Webview::Webview
      getter handle : Pointer(Void)
      getter app : App
      getter active : Set(Symbol)

      def initialize(@wv : Webview::Webview, @handle : Pointer(Void), @app : App, @active : Set(Symbol))
      end

      def dep_active?(id : Symbol) : Bool
        @active.includes?(id)
      end
    end

    # Snapshot of main-runtime state — wired into plugins that need to
    # orchestrate the main webview (e.g. opening secondary windows from the
    # `Windows` plugin). Delivered after the main `Bridge` is wired and
    # the binding set is final, so `bindings` is a stable snapshot.
    struct MainCtx
      getter wv : Webview::Webview
      getter app : App
      getter resolved : Plugins::ResolvedSet
      getter bindings : Array(Binding)

      def initialize(@wv : Webview::Webview, @app : App, @resolved : Plugins::ResolvedSet, @bindings : Array(Binding))
      end
    end

    # -------------------------------------------------------------------------
    # Phase modules — include only the phases a plugin participates in.
    # The compiler then enforces the abstract method for that phase. Binding
    # registration is opt-in via `include Lune::Bindable` + `@[Bind]` and is
    # handled separately from these lifecycle hooks.
    # -------------------------------------------------------------------------

    # Include if the plugin needs the webview object itself (wv.bind /
    # wv.dispatch / wv.eval). Boot-time JS injection goes through `init_js`.
    module WebviewInject
      abstract def init_webview(ctx : WebviewCtx) : Nil
    end

    # Include if this plugin holds resources that must be released on quit.
    module Lifecycle
      abstract def shutdown : Nil
    end

    # Include if this plugin needs a handle to the main webview / app /
    # final binding set after the bridge has been wired (e.g. to open
    # secondary windows or eval into the main webview at runtime).
    module MainContextAware
      abstract def set_main_context(ctx : MainCtx) : Nil
    end

    # -------------------------------------------------------------------------
    # Base — existing interface kept intact while migration is in progress.
    # -------------------------------------------------------------------------

    abstract def descriptor : Descriptor

    # Overridden by Lune::Bindable's macro to register annotated methods.
    def install(app : Lune::App) : Nil
    end

    # Boot-time JS the runner injects via `wv.init`. Return nil to skip.
    def init_js : String?
      nil
    end

    def name : String
      descriptor.id.to_s
    end

    # Binding namespace follows the Crystal module path of the plugin class
    # verbatim. So `Lune::Plugins::Tray` becomes `Lune::Plugins::Tray`, which
    # `Binding#id` later renders as `Lune.Plugins.Tray.<method>` on the JS
    # side. Following the Crystal namespace 1-to-1 keeps the rule predictable
    # (no special stripping) and prevents collisions with user `Bindable`
    # classes — a user `class Tray` exports under `api.Tray`, the plugin
    # exports under `runtime.Lune.Plugins.Tray`.
    def binding_namespace : String
      self.class.name
    end

    # True iff this plugin ships with the framework. The check keys off the
    # Crystal module path — every first-party plugin lives under
    # `Lune::Plugins::*` (and `register_builtins!` only registers things
    # from there). A third-party shard would have to monkey-patch the
    # `Lune::Plugins` module to forge this, which is deliberate, visible,
    # and an obvious "don't do that" signal.
    def built_in? : Bool
      self.class.name.starts_with?("Lune::Plugins::")
    end

    def sentinel_key : String
      "#{SENTINEL_NS}.#{name}"
    end

    # Returns the `opts.<name>` accessor this plugin claims on `Lune::Options`,
    # or nil if the plugin didn't declare a `config` block. Used by `Lune.use`
    # to fail early on collision instead of letting Crystal's silent method
    # redefinition decide which plugin wins. Plugins using `config` get this
    # overridden via the macro; plugins without config keep the nil default.
    def lune_options_accessor : Symbol?
      nil
    end

    # Phase 0: pull options / handle into instance vars before install or init_webview.
    def setup(ctx : SetupCtx) : Nil
    end

    # Declares a plugin's typed config. Inside the block, write `property`
    # declarations as you would in any class. The macro:
    #
    #   1. Generates a nested `Config` class with those properties.
    #   2. Adds `@config : Config = Config.new` and `getter config : Config`
    #      to the plugin so the plugin reads its own settings off `@config`.
    #   3. Reopens `Lune::Options` with a typed accessor whose name is the
    #      plugin's simple class name underscored — `Tray` → `opts.tray`,
    #      `WindowDrag` → `opts.window_drag`. Both `opts.tray.icon = …` and
    #      `opts.tray { |t| t.icon = … }` work; both return / yield the
    #      same `Config` instance that the plugin reads in `setup`.
    #
    # The accessor walks `Lune.registered_plugins` at call time, so the plugin
    # must be registered via `Lune.use(...)` (or via the load-time
    # `register_builtins!` for first-party plugins) before any `opts.<id>`
    # access. Direct mutations on the returned config persist on the plugin
    # instance — `setup(ctx)` later observes whatever the user assigned in
    # the `Lune.run` block.
    macro config(accessor = nil, &block)
      class Config
        {{ block.body }}

        def initialize
        end
      end

      @config : Config = Config.new
      getter config : Config

      {% if accessor %}
        {% accessor_name = accessor.id %}
      {% else %}
        {% accessor_name = @type.name.split("::").last.underscore.id %}
      {% end %}

      def lune_options_accessor : Symbol?
        :{{ accessor_name }}
      end

      class ::Lune::Options
        def {{ accessor_name }} : {{ @type }}::Config
          plugin = ::Lune.registered_plugins.find { |p| p.is_a?({{ @type }}) }
          raise "plugin :{{ accessor_name }} referenced before Lune.use" unless plugin
          plugin.as({{ @type }}).config
        end

        def {{ accessor_name }}(& : {{ @type }}::Config ->) : Nil
          yield {{ accessor_name }}
        end
      end
    end

    def configured? : Bool
      false
    end

    def js_helpers : String
      ""
    end

    def dts_helpers : String
      ""
    end

    # Emitted into runtime.js for plugins filtered out by `platforms`.
    # Each method on the namespace should reject with a LuneError so user code
    # can `.catch` and fall back gracefully instead of hitting a TypeError from
    # `undefined` namespace access. Default nil = no stub emitted.
    def unavailable_js_stub(platform : Symbol) : String?
      nil
    end

    # Type-side counterpart. Same signatures as the live plugin so user code
    # type-checks identically across platforms.
    def unavailable_dts_stub : String?
      nil
    end
  end
end
