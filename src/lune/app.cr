require "vow/manifest"

module Lune
  class App
    getter bindings = [] of Binding
    # Captured `Vow::TypeDescriptor`s for the surface types reachable from the
    # registered bindings — populated by the `Bindable` macro alongside each
    # binding, split by surface so each interface lands in the right generated
    # `.d.ts` (`plugin_types` → `runtime.d.ts`, `user_types` → `App.d.ts`).
    getter plugin_types = [] of Vow::TypeDescriptor
    getter user_types = [] of Vow::TypeDescriptor
    property bridge : Bridge?
    property title : String = ""
    property menu_options : Options::Menu = Options::Menu.new
    # Native top-level window handle. Set by the runner once `wv.native_handle`
    # resolves; consumed by menu rebuilds (`update_menu`, `set_menu`) since
    # Win32 `SetMenu` needs the HWND. macOS ignores the value.
    property window_handle : Void* = Pointer(Void).null
    getter event : Event
    getter stream : Stream

    @async_pool : Fiber::ExecutionContext::Parallel? = nil

    def initialize
      @bindings = [] of Binding
      @bridge = nil
      @extra_bridges = [] of Bridge
      @event = Event.new(-> { @bridge }, @extra_bridges)
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
      mods.each(&.install(self))
    end

    # ----------------------------
    # Bindings
    # ----------------------------

    def register(binding : Binding)
      @bindings << binding
    end

    # Records captured surface types for a bindable surface. *internal* is the
    # class's plugin-ness (it routes the interfaces to the right `.d.ts`).
    def register_types(types : Array(Vow::TypeDescriptor), internal : Bool) : Nil
      (internal ? @plugin_types : @user_types).concat(types)
    end

    # The static `Vow::Manifest` for everything registered on this app — the
    # contract behind the generated client and introspection, derived from the
    # current binding set and the captured surface types.
    def manifest : Vow::Manifest
      Lune::Generator.manifest(@bindings, @plugin_types + @user_types)
    end

    # Replaces the application menu bar at runtime.
    def set_menu(& : Options::Menu ->)
      opts = Options::Menu.new
      yield opts
      @menu_options = opts
      Native::Menu.set_from_options(@window_handle, opts, @title)
    end

    # Re-applies the current menu after mutating `MenuItem` properties
    # (e.g. `item.enabled = false`).
    def update_menu
      Native::Menu.set_from_options(@window_handle, @menu_options, @title)
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
  end
end
