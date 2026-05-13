module Lune
  class App
    getter bindings = [] of BindingDef
    getter title
    property bridge : Bridge?

    def initialize
      @bindings = [] of BindingDef
      @bridge = nil # Injected once webview is created
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
      name : String,
      namespace : String,
      args : Array(String),
      return_type : String,
      async : Bool,
      &block : Array(JSON::Any) -> JSON::Any
    )
      @bindings << external_binding(name, namespace, args, return_type, async, &block)
    end

    # ----------------------------
    # Events
    # ----------------------------

    def emit(event : String, data = nil)
      json = data.nil? ? "null" : data.to_json
      with_bridge.dispatch_eval("window.__lune_emit(#{event.inspect}, #{json})")
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
    private def with_bridge
      @bridge.not_nil!
    end

    private def external_binding(
      name : String,
      namespace : String,
      args : Array(String),
      return_type : String,
      async : Bool,
      &block : Array(JSON::Any) -> JSON::Any
    )
      BindingDef.new(
        name: name,
        namespace: namespace,
        args: args,
        return_type: return_type,
        callback: block,
        async: async
      )
    end
  end
end
