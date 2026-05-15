module Lune
  class App
    getter bindings = [] of Binding
    getter title
    property bridge : Bridge?

    def initialize
      @bindings = [] of Binding
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
      namespace : String,
      method : String,
      args : Array(String),
      return_type : String,
      async : Bool,
      &block : Array(JSON::Any) -> JSON::Any
    )
      @bindings << external_binding(namespace, method, args, return_type, async, &block)
    end

    # ----------------------------
    # Events
    # ----------------------------

    def emit(event : String, data = nil)
      return unless (b = @bridge)
      json = data.nil? ? "null" : data.to_json
      b.dispatch_eval("window.__lune_emit(#{event.inspect}, #{json})")
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

    private def external_binding(
      namespace : String,
      method : String,
      args : Array(String),
      return_type : String,
      async : Bool,
      &block : Array(JSON::Any) -> JSON::Any
    )
      Binding.new(
        namespace: namespace,
        method: method,
        args: args,
        return_type: return_type,
        callback: block,
        async: async
      )
    end
  end
end
