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
      @arg_transforms : Array(String?) = [] of String?,
      @ts_args : Array(String?) = [] of String?,
    )
      @internal = internal
      @async = async
    end

    def id
      return @method if @namespace.empty?
      "#{@namespace.split("::").join(".")}.#{@method}"
    end

    def js_func_name
      # casts method name to camelCase
      # ping -> ping
      # ping_me -> pingMe
      @method.camelcase(lower: true)
    end

    def to_js_stub : String
      names = resolved_arg_names
      params = names.join(", ")
      call_args = call_arg_exprs(names)
      call_tail = call_args.empty? ? "" : ", #{call_args.join(", ")}"
      "  #{js_func_name}(#{params}) {\n    return __lune.call(#{id.inspect}#{call_tail});\n  },"
    end

    def to_dts_sig : String
      "  #{js_func_name}(#{dts_params}): Promise<#{dts_return_type}>;"
    end

    def dts_return_type
      Lune::Runtime::Generator.crystal_to_ts(@return_type)
    end

    def dts_params
      resolved_arg_names.each_with_index.map { |name, i|
        ts = @ts_args[i]? || Lune::Runtime::Generator.crystal_to_ts(@args[i])
        "#{name}: #{ts}"
      }.join(", ")
    end

    def internal?
      @internal
    end

    protected def resolved_arg_names : Array(String)
      @arg_names.empty? ? Array(String).new(@args.size) { |i| "arg#{i}" } : @arg_names
    end

    protected def call_arg_exprs(names : Array(String)) : Array(String)
      names.map_with_index { |name, i| @arg_transforms[i]? || name }
    end
  end
end
