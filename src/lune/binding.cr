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
      "  #{js_func_name}(#{dts_params}): Promise<#{dts_return_type}>;"
    end

    def dts_return_type
      Lune::Runtime::Generator.crystal_to_ts(@return_type)
    end

    def dts_params
      @args.each_with_index.map { |t, i| "arg#{i}: #{Lune::Runtime::Generator.crystal_to_ts(t)}" }.join(", ")
    end

    def internal?
      @internal
    end
  end
end
