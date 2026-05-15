module Lune
  class RuntimeBinding < Lune::Binding
    def initialize(
      @namespace : String,
      @method : String,
      @args : Array(String),
      @return_type : String,
      @callback : Proc(Array(JSON::Any), JSON::Any),
      async : Bool = false,
      @arg_names : Array(String) = [] of String,
      @ts_return_type : String? = nil,
    )
      @internal = true
      @async = async
    end

    def js_func_name : String
      @method.lchop("__lune.")
    end

    def to_js_stub : String
      names = resolved_arg_names
      params = names.join(", ")
      call_args = names.empty? ? "" : ", #{names.join(", ")}"
      "export function #{js_func_name}(#{params}) { return __lune.call(#{id.inspect}#{call_args}); }"
    end

    def to_dts_sig : String
      names = resolved_arg_names
      params = names.zip(@args).map { |n, t| "#{n}: #{Lune::Runtime::Generator.crystal_to_ts(t)}" }.join(", ")
      ret = @ts_return_type || "Promise<#{dts_return_type}>"
      "export declare function #{js_func_name}(#{params}): #{ret};"
    end

    private def resolved_arg_names : Array(String)
      @arg_names.empty? ? Array(String).new(@args.size) { |i| "arg#{i}" } : @arg_names
    end
  end
end
