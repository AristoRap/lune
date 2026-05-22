module Lune
  abstract class Plugin
    include Lune::Installable

    BRIDGE_MARKER = "__lune"
    SENTINEL_NS   = "plugins.#{BRIDGE_MARKER}"

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
      platforms : Array(Symbol) = [:darwin, :linux, :win32] # OSes where the cap can run; filtered out elsewhere

    # -------------------------------------------------------------------------
    # Context structs — passed to each lifecycle phase instead of raw args.
    # -------------------------------------------------------------------------

    struct SetupCtx
      getter options : Options
      getter handle : Pointer(Void)

      def initialize(@options : Options, @handle : Pointer(Void))
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

    def binding_namespace : String
      name.camelcase
    end

    def sentinel_key : String
      "#{SENTINEL_NS}.#{name}"
    end

    # Phase 0: pull options / handle into instance vars before install or init_webview.
    def setup(ctx : SetupCtx) : Nil
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
