module Lune
  abstract class Capability
    BRIDGE_MARKER = "__lune"
    SENTINEL_NS   = "capabilities.#{BRIDGE_MARKER}"

    # -------------------------------------------------------------------------
    # Descriptor — static self-description for each capability.
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

    struct BindCtx
      getter app : App
      getter cap : Lune::Capability

      def initialize(@app : App, @cap : Lune::Capability)
      end

      delegate register, to: @app

      # Register a bridge binding under this capability's JS namespace.
      # `method` is the leaf name (no capability prefix); the full bridge ID
      # becomes `__lune.<cap-name>.<method>` and the JS path becomes
      # `<Cap.binding_namespace>.<methodCamelCase>(...)`.
      def define(
        method : String,
        args : Array(String) = [] of String,
        return_type : String = "Nil",
        arg_names : Array(String) = [] of String,
        arg_transforms : Array(String?) = [] of String?,
        ts_args : Array(String?) = [] of String?,
        ts_return_type : String? = nil,
        async : Bool = false,
        &callback : Array(JSON::Any) -> JSON::Any
      ) : Nil
        @app.register(Lune::RuntimeBinding.new(
          js_namespace: @cap.binding_namespace,
          method: "#{@cap.name}.#{method}",
          args: args,
          return_type: return_type,
          callback: callback,
          async: async,
          arg_names: arg_names,
          arg_transforms: arg_transforms,
          ts_args: ts_args,
          ts_return_type: ts_return_type,
        ))
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

    # Snapshot of main-runtime state — wired into capabilities that need to
    # orchestrate the main webview (e.g. opening secondary windows from the
    # `Windows` capability). Delivered after the main `Bridge` is wired and
    # the binding set is final, so `bindings` is a stable snapshot.
    struct MainCtx
      getter wv : Webview::Webview
      getter app : App
      getter resolved : Capabilities::ResolvedSet
      getter bindings : Array(Binding)

      def initialize(@wv : Webview::Webview, @app : App, @resolved : Capabilities::ResolvedSet, @bindings : Array(Binding))
      end
    end

    # -------------------------------------------------------------------------
    # Phase modules — include only the phases a capability participates in.
    # The compiler then enforces the abstract method for that phase.
    # -------------------------------------------------------------------------

    # Include if this capability registers bridge bindings (also runs in build mode).
    module BindPhase
      abstract def install(ctx : BindCtx) : Nil
    end

    # Include if this capability injects JS or registers raw wv.bind calls (runtime only).
    module WebviewInject
      abstract def init_webview(ctx : WebviewCtx) : Nil
    end

    # Include if this capability holds resources that must be released on quit.
    module Lifecycle
      abstract def shutdown : Nil
    end

    # Include if this capability needs a handle to the main webview / app /
    # final binding set after the bridge has been wired (e.g. to open
    # secondary windows or eval into the main webview at runtime).
    module MainContextAware
      abstract def set_main_context(ctx : MainCtx) : Nil
    end

    # -------------------------------------------------------------------------
    # Base — existing interface kept intact while migration is in progress.
    # -------------------------------------------------------------------------

    abstract def descriptor : Descriptor

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
    # Default no-op — stateless capabilities don't need to override.
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

    # Emitted into runtime.js for capabilities filtered out by `platforms`.
    # Each method on the namespace should reject with a LuneError so user code
    # can `.catch` and fall back gracefully instead of hitting a TypeError from
    # `undefined` namespace access. Default nil = no stub emitted.
    def unavailable_js_stub(platform : Symbol) : String?
      nil
    end

    # Type-side counterpart. Same signatures as the live capability so user code
    # type-checks identically across platforms.
    def unavailable_dts_stub : String?
      nil
    end
  end
end
