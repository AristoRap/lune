module Lune
  # A registered call from JS to Crystal. One class for both user-class bindings
  # (`api.MyClass.method` in `app.js`) and framework bindings (`Namespace.method`
  # in `runtime.js`). The `internal?` flag selects between the two output shapes:
  #
  # - `internal: false` — user binding. Bridge id is `<namespace>.<method>`,
  #   JS func name is `camelcase(method)`, JS stub formatted for `app.js`.
  # - `internal: true`  — framework binding. Bridge id is `__lune.<method>`,
  #   JS func name is the camelcased leaf (after the last `.` in `method`),
  #   JS stub formatted for `runtime.js`. The TS return type can be overridden
  #   via `ts_return_type` (bypasses the default `Promise<T>` wrap).
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
      @ts_return_type : String? = nil,
    )
      @internal = internal
      @async = async
    end

    def id : String
      if @internal
        "#{Lune::Capability::BRIDGE_MARKER}.#{@method}"
      else
        @namespace.empty? ? @method : "#{@namespace.split("::").join(".")}.#{@method}"
      end
    end

    # User bindings camelcase the whole method name. Framework bindings carry a
    # capability-prefixed path (`clipboard.read_html`) and only the leaf is the
    # JS function name.
    def js_func_name : String
      @internal ? @method.split(".").last.camelcase(lower: true) : @method.camelcase(lower: true)
    end

    def to_js_stub : String
      names = resolved_arg_names
      params = names.join(", ")
      call_args = call_arg_exprs(names)
      call_tail = call_args.empty? ? "" : ", #{call_args.join(", ")}"
      if @internal
        "  #{js_func_name}(#{params}) { return __lune.call(#{id.inspect}#{call_tail}); },"
      else
        "  #{js_func_name}(#{params}) {\n    return __lune.call(#{id.inspect}#{call_tail});\n  },"
      end
    end

    def to_dts_sig : String
      if ret = @ts_return_type
        "  #{js_func_name}(#{dts_params}): #{ret};"
      else
        "  #{js_func_name}(#{dts_params}): Promise<#{dts_return_type}>;"
      end
    end

    def dts_return_type
      Lune::Generator.crystal_to_ts(@return_type)
    end

    def dts_params
      resolved_arg_names.each_with_index.map { |name, i|
        ts = @ts_args[i]? || Lune::Generator.crystal_to_ts(@args[i])
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
