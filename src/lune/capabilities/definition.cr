module Lune
  module Capabilities
    # Value object that encodes the naming convention and produces a RuntimeBinding.
    # `name` must include the camelCase capability prefix, e.g. "clipboard.read".
    # The bridge ID becomes: BRIDGE_MARKER + "." + name = "__lune.clipboard.read".
    # `binding(js_namespace)` receives the PascalCase namespace used for JS grouping,
    # e.g. "Clipboard" — so the generator emits Clipboard.Read() in the output.
    class Definition
      def initialize(
        @name : String,
        @args : Array(String),
        @return_type : String,
        @callback : Proc(Array(JSON::Any), JSON::Any),
        @async : Bool = false,
        @arg_names : Array(String) = [] of String,
        @ts_return_type : String? = nil,
      )
      end

      def binding(js_namespace : String) : Lune::RuntimeBinding
        Lune::RuntimeBinding.new(
          js_namespace: js_namespace,
          method: @name,
          args: @args,
          return_type: @return_type,
          callback: @callback,
          async: @async,
          arg_names: @arg_names,
          ts_return_type: @ts_return_type
        )
      end
    end
  end
end
