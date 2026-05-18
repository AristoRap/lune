module Lune
  class RuntimeBinding < Lune::Binding
    def initialize(
      js_namespace : String,
      method : String,
      args : Array(String),
      return_type : String,
      callback : Proc(Array(JSON::Any), JSON::Any),
      async : Bool = false,
      arg_names : Array(String) = [] of String,
      @ts_return_type : String? = nil,
    )
      super(
        namespace: js_namespace,
        method: method,
        args: args,
        return_type: return_type,
        callback: callback,
        internal: true,
        async: async,
        arg_names: arg_names,
      )
    end

    # Bridge ID: "__lune.<capability>.<method>" — BRIDGE_MARKER is always the root.
    # e.g. "__lune.clipboard.read", "__lune.lifecycle.quit"
    def id : String
      "#{Lune::Capability::BRIDGE_MARKER}.#{@method}"
    end

    # camelCase leaf name, e.g. "clipboard.read_html" → "readHtml"
    def js_func_name : String
      @method.split(".").last.camelcase(lower: true)
    end

    # PascalCase leaf name for use as the object method name, e.g. "read_html" → "ReadHtml"
    def js_method_name : String
      @method.split(".").last.camelcase
    end

    # Object-method body for the generated `export const Namespace = { … }` block.
    def to_js_stub : String
      names = resolved_arg_names
      params = names.join(", ")
      call_args = names.empty? ? "" : ", #{names.join(", ")}"
      "  #{js_method_name}(#{params}) { return __lune.call(#{id.inspect}#{call_args}); },"
    end

    # Interface member for the generated `export interface Namespace { … }` block.
    def to_dts_sig : String
      ret = @ts_return_type || "Promise<#{dts_return_type}>"
      "  #{js_method_name}(#{dts_params}): #{ret};"
    end
  end
end
