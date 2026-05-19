module Lune
  class App
    getter bindings = [] of Binding
    property bridge : Bridge?
    property title : String = ""
    property menu_options : Options::Menu = Options::Menu.new
    property channel_sender : Proc(String, String, Nil)?

    def initialize
      @bindings = [] of Binding
      @bridge = nil
      @event_handlers = {} of String => Array(Proc(JSON::Any, Nil))
      @event_once_handlers = {} of String => Array(Proc(JSON::Any, Nil))
      @channel_sender = nil
      @channel_handlers = {} of String => Array(Proc(JSON::Any, Nil))
      @async_pool = Fiber::ExecutionContext::Parallel.new("lune-tasks", System.cpu_count)
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

    # ----------------------------
    # Events
    # ----------------------------

    def emit(event : String, data = nil)
      return unless (b = @bridge)
      json = data.nil? ? "null" : data.to_json
      b.dispatch_eval("window.#{Lune::Capability::BRIDGE_MARKER}.crystalEmit(#{event.inspect}, #{json})")
    end

    def on(event : String, &block : JSON::Any -> Nil)
      (@event_handlers[event] ||= [] of Proc(JSON::Any, Nil)) << block
    end

    def once(event : String, &block : JSON::Any -> Nil)
      (@event_once_handlers[event] ||= [] of Proc(JSON::Any, Nil)) << block
    end

    def off(event : String)
      @event_handlers.delete(event)
      @event_once_handlers.delete(event)
    end

    # ----------------------------
    # Channel (WebSocket IPC)
    # ----------------------------

    def channel_send(name : String, data = nil)
      return unless (s = @channel_sender)
      json = data.nil? ? "null" : data.to_json
      s.call(name, json)
    end

    def channel_on(name : String, &block : JSON::Any -> Nil)
      (@channel_handlers[name] ||= [] of Proc(JSON::Any, Nil)) << block
    end

    def channel_off(name : String)
      @channel_handlers.delete(name)
    end

    def dispatch_channel_message(name : String, data : JSON::Any)
      @channel_handlers[name]?.try(&.each(&.call(data)))
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

    def dispatch_event(event : String, data : JSON::Any)
      @event_handlers[event]?.try(&.each(&.call(data)))
      @event_once_handlers.delete(event).try(&.each(&.call(data)))
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
