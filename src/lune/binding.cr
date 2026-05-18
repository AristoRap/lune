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
      @arg_names : Array(String) = [] of String,
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
      names = resolved_arg_names
      params = names.join(", ")
      call_args = names.empty? ? "" : ", #{names.join(", ")}"
      "  #{js_func_name}(#{params}) {\n    return __lune.call(#{id.inspect}#{call_args});\n  },"
    end

    def to_dts_sig : String
      "  #{js_func_name}(#{dts_params}): Promise<#{dts_return_type}>;"
    end

    def dts_return_type
      Lune::Runtime::Generator.crystal_to_ts(@return_type)
    end

    def dts_params
      resolved_arg_names.zip(@args).map { |name, t|
        "#{name}: #{Lune::Runtime::Generator.crystal_to_ts(t)}"
      }.join(", ")
    end

    def internal?
      @internal
    end

    protected def resolved_arg_names : Array(String)
      @arg_names.empty? ? Array(String).new(@args.size) { |i| "arg#{i}" } : @arg_names
    end
  end
end
