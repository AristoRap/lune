module Lune
  class App
    getter bindings = [] of Binding
    getter title
    property bridge : Bridge?

    def initialize
      @bindings = [] of Binding
      @bridge = nil
      @event_handlers = {} of String => Array(Proc(JSON::Any, Nil))
      @event_once_handlers = {} of String => Array(Proc(JSON::Any, Nil))
    end

    # ----------------------------
    # Plugin system
    # ----------------------------

    def install(*mods : Installable)
      mods.each do |mod|
        mod.install(self)
      end
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
      b.dispatch_eval("window.__lune_emit(#{event.inspect}, #{json})")
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
