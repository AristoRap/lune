module Lune
  class App
    getter bindings = [] of Binding
    property bridge : Bridge?
    property title : String = ""
    property menu_options : Options::Menu = Options::Menu.new
    getter events : Events
    getter stream : Stream

    @async_pool : Fiber::ExecutionContext::Parallel? = nil

    def initialize
      @bindings = [] of Binding
      @bridge = nil
      @extra_bridges = [] of Bridge
      @events = Events.new(-> { @bridge }, @extra_bridges)
      @stream = Stream.new
    end

    def add_bridge(b : Bridge) : Nil
      @extra_bridges << b
    end

    def remove_bridge(b : Bridge) : Nil
      @extra_bridges.delete(b)
    end

    # ----------------------------
    # Plugin system
    # ----------------------------

    def install(*mods : Installable)
      mods.each do |mod|
        mod.install(self)
      end
    end

    def install(cap : Capability)
      cap.install(Capability::BindCtx.new(self, cap)) if cap.is_a?(Capability::BindPhase)
    end

    # ----------------------------
    # Bindings
    # ----------------------------

    def bind(
      namespace : String,
      method : String,
      args : Array(String),
      return_type : String,
      async : Bool,
      runtime : Bool = false,
      arg_names : Array(String) = [] of String,
      &block : Array(JSON::Any) -> JSON::Any
    )
      @bindings << add_binding(namespace, method, args, return_type, async, runtime, arg_names, &block)
    end

    def register(binding : Binding)
      @bindings << binding
    end

    # Replaces the application menu bar at runtime.
    def set_menu(& : Options::Menu ->)
      opts = Options::Menu.new
      yield opts
      @menu_options = opts
      Native::Menu.set_from_options(opts, @title)
    end

    # Re-applies the current menu after mutating `MenuItem` properties
    # (e.g. `item.enabled = false`).
    def update_menu
      Native::Menu.set_from_options(@menu_options, @title)
    end

    # The Parallel ExecutionContext owns a kqueue + worker threads. Allocating
    # one eagerly in `initialize` made `Lune::App.new` expensive enough to
    # exhaust the per-process fd limit in test suites that instantiate many
    # apps. Lazy-init so only apps that actually call `#async` pay the cost.
    def async(name : String = "lune-task", &block : ->) : Nil
      pool = @async_pool ||= Fiber::ExecutionContext::Parallel.new("lune-tasks", System.cpu_count)
      pool.spawn(name: name, &block)
    end

    # ----------------------------
    # JS eval
    # ----------------------------

    def eval(js : String)
      bridge = @bridge
      raise BridgeNotReadyError.new("App#eval called before the runner wired the bridge") if bridge.nil?
      bridge.dispatch_eval(js)
    end

    # ----------------------------
    # Internal
    # ----------------------------

    def close!
      @bridge.try(&.close!)
    end

    private def add_binding(
      namespace : String,
      method : String,
      args : Array(String),
      return_type : String,
      async : Bool,
      runtime : Bool = false,
      arg_names : Array(String) = [] of String,
      &block : Array(JSON::Any) -> JSON::Any
    )
      Binding.new(
        namespace: namespace,
        method: method,
        args: args,
        return_type: return_type,
        callback: block,
        async: async,
        internal: runtime,
        arg_names: arg_names
      )
    end
  end
end
