module Lune
  class App
    class Events
      def initialize(@bridge_fn : -> Bridge?, @extra_bridges : Array(Bridge))
        @handlers = {} of String => Array(Proc(JSON::Any, Nil))
        @once_handlers = {} of String => Array(Proc(JSON::Any, Nil))
      end

      def emit(event : String, data = nil)
        return unless (b = @bridge_fn.call)
        json = data.nil? ? "null" : data.to_json
        bm = Lune::Capability::BRIDGE_MARKER
        b.dispatch_eval("if(window.#{bm}&&typeof window.#{bm}.crystalEmit==='function')window.#{bm}.crystalEmit(#{event.inspect},#{json})")
        @extra_bridges.each(&.dispatch_eval("if(window.#{bm}&&typeof window.#{bm}.crystalEmit==='function')window.#{bm}.crystalEmit(#{event.inspect},#{json})"))
      end

      def on(event : String, &block : JSON::Any -> Nil)
        (@handlers[event] ||= [] of Proc(JSON::Any, Nil)) << block
      end

      def once(event : String, &block : JSON::Any -> Nil)
        (@once_handlers[event] ||= [] of Proc(JSON::Any, Nil)) << block
      end

      def off(event : String)
        @handlers.delete(event)
        @once_handlers.delete(event)
      end

      def dispatch(event : String, data : JSON::Any)
        @handlers[event]?.try(&.each(&.call(data)))
        @once_handlers.delete(event).try(&.each(&.call(data)))
      end
    end

    class Stream
      property sender : Proc(String, String, Nil)?

      def initialize
        @sender = nil
        @handlers = {} of String => Array(Proc(JSON::Any, Nil))
      end

      def send(name : String, data = nil)
        return unless (s = @sender)
        json = data.nil? ? "null" : data.to_json
        s.call(name, json)
      end

      def on(name : String, &block : JSON::Any -> Nil)
        (@handlers[name] ||= [] of Proc(JSON::Any, Nil)) << block
      end

      def off(name : String)
        @handlers.delete(name)
      end

      def dispatch(name : String, data : JSON::Any)
        @handlers[name]?.try(&.each(&.call(data)))
      end
    end

    getter bindings = [] of Binding
    property bridge : Bridge?
    property title : String = ""
    property menu_options : Options::Menu = Options::Menu.new
    getter events : Events
    getter stream : Stream

    def initialize
      @bindings = [] of Binding
      @bridge = nil
      @extra_bridges = [] of Bridge
      @events = Events.new(-> { @bridge }, @extra_bridges)
      @stream = Stream.new
      @async_pool = Fiber::ExecutionContext::Parallel.new("lune-tasks", System.cpu_count)
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
      cap.install(Capability::BindCtx.new(self)) if cap.is_a?(Capability::Bindable)
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

    def async(name : String = "lune-task", &block : ->) : Nil
      @async_pool.spawn(name: name, &block)
    end

    # ----------------------------
    # JS eval
    # ----------------------------

    def eval(js : String)
      with_bridge.dispatch_eval(js)
    end

    # ----------------------------
    # Internal
    # ----------------------------

    def close!
      with_bridge.close!
    end

    # Ensure bridge was injected before use
    def with_bridge
      @bridge.not_nil!
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
