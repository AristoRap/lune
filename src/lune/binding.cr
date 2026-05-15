module Lune
  class Binding
    getter namespace, method, args, return_type, callback, async

    def initialize(
      @namespace : String,
      @method : String,
      @args : Array(String),
      @return_type : String,
      @callback : Proc(Array(JSON::Any), JSON::Any),
      internal : Bool = false,
      async : Bool = false,
    )
      @internal = internal
      @async = async
    end

    def id
      return @method if @namespace.empty?
      "#{@namespace.split("::").join(".")}.#{@method}"
    end

    def js_func_name
      # casts method name to PascalCase
      # ping -> Ping
      # ping_me -> PingMe
      @method.camelcase(lower: false)
    end

    def to_js_stub : String
      "  #{js_func_name}(...args) {\n    return __lune.call(#{id.inspect}, ...args);\n  },"
    end

    def to_dts_sig : String
      ret = Lune::Runtime::Generator.crystal_to_ts(@return_type)
      params = @args.each_with_index.map { |t, i| "arg#{i}: #{Lune::Runtime::Generator.crystal_to_ts(t)}" }.join(", ")
      "  #{js_func_name}(#{params}): Promise<#{ret}>;"
    end

    def internal?
      @internal
    end
  end
end
