module Lune
  class App
    include Bindable

    def initialize(@bridge : Bridge, @prefix : String? = nil)
    end

    # ----------------------------
    # Bindable — concrete impl
    # ----------------------------

    def bind(name : String, &block : Array(JSON::Any) -> JSON::Any)
      @bridge.bind(scoped(name), &block)
    end

    def bind_async(name : String, &block : Array(JSON::Any) -> JSON::Any)
      @bridge.bind_async(scoped(name), &block)
    end

    # ----------------------------
    # Namespace
    # ----------------------------

    # Returns a scoped App whose bindings are prefixed with `name`.
    # Nesting is supported: namespaces compose dot-separated.
    #
    #   app.namespace("math") do |math|
    #     math.namespace("trig") do |trig|   # registers as "math.trig.*"
    #       trig.bind_typed("sin", Float64) { |x| Math.sin(x) }
    #     end
    #   end
    def namespace(name : String, &)
      child_prefix = @prefix ? "#{@prefix}.#{name}" : name
      yield App.new(@bridge, child_prefix)
    end

    # ----------------------------
    # Plugin system
    # ----------------------------

    def install(mod : Installable)
      mod.install(self)
    end

    # ----------------------------
    # Events
    # ----------------------------

    def emit(event : String, data = nil)
      name = scoped(event)
      json = data.nil? ? "null" : data.to_json
      @bridge.eval("window.__lune_emit(#{name.inspect}, #{json})")
    end

    # ----------------------------
    # JS eval
    # ----------------------------

    def eval(js : String)
      @bridge.eval(js)
    end

    # ----------------------------
    # Internal
    # ----------------------------

    def binding_names : Array(String)
      @bridge.binding_names
    end

    def close!
      @bridge.close!
    end

    private def scoped(name : String) : String
      @prefix ? "#{@prefix}.#{name}" : name
    end
  end
end
