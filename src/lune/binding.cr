require "vow/manifest"
require "vow/context"

module Lune
  # A registered call from JS to Crystal. One class for both user-class bindings
  # (`api.MyClass.method` in `app.js`) and plugin bindings (`Namespace.method`
  # in `runtime.js`). User and plugin bindings share the same id / js_func_name /
  # stub shape; the `internal?` flag only decides which JS file the binding
  # lands in (Generator emits user bindings to `app/App.js`, internal bindings
  # to `plugins/<id>.js`). The TS return type can be overridden via
  # `ts_return_type` (bypasses the default `Promise<T>` wrap).
  class Binding
    getter namespace, method, args, return_type, callback, async

    def initialize(
      @namespace : String,
      @method : String,
      @args : Array(String),
      @return_type : String,
      @callback : Proc(Hash(String, JSON::Any), ::Vow::Context?, JSON::Any),
      internal : Bool = false,
      async : Bool = false,
      @arg_names : Array(String) = [] of String,
      @ts_args : Array(String?) = [] of String?,
      @ts_return_type : String? = nil,
    )
      @internal = internal
      @async = async
    end

    # The named-object wire keys for this binding's args — the resolved arg name
    # (override or Crystal param) camelCased, the same key the client sends, the
    # callback decodes, and the `.d.ts` declares.
    def arg_keys : Array(String)
      resolved_arg_names.map(&.camelcase(lower: true))
    end

    def id : String
      @namespace.empty? ? @method : "#{@namespace.split("::").join(".")}.#{@method}"
    end

    def js_func_name : String
      @method.camelcase(lower: true)
    end

    def to_js_stub : String
      # The single named-args object is forwarded as-is; its keys are typed by
      # the `.d.ts`. A zero-arg stub defaults it to `{}` so `fn()` stays callable.
      param = @args.empty? ? "args = {}" : "args"
      "  #{js_func_name}(#{param}) {\n    return __lune.call(#{id.inspect}, args);\n  },"
    end

    # JS-side runtime that every per-binding stub from `#to_js_stub` calls
    # into: looks up the registered window function, awaits it, and rewraps
    # typed Crystal errors as `LuneError`. One copy lives at the top of
    # `runtime.js`; per-binding stubs reference it by name.
    def self.js_runtime : String
      <<-JS
        export const __lune = {
          call(name, args) {
            return window[name](args).catch(function(err) {
              if (err !== null && typeof err === 'object' && typeof err.code === 'string') {
                throw new LuneError(err.code, err.error);
              }
              throw err;
            });
          },
        };
        JS
    end

    # *known* maps a captured surface type's Crystal name (full and basename) to
    # its generated TS interface name, so a struct reference in the signature
    # resolves to that interface instead of raising. Defaults to empty for the
    # common primitive-only case and for callers that don't build a manifest.
    def to_dts_sig(known : Hash(String, String) = {} of String => String) : String
      if ret = @ts_return_type
        "  #{js_func_name}(#{dts_params(known)}): #{ret};"
      else
        "  #{js_func_name}(#{dts_params(known)}): Promise<#{dts_return_type(known)}>;"
      end
    end

    def dts_return_type(known : Hash(String, String) = {} of String => String)
      Lune::Generator.crystal_return_to_ts(@return_type, known)
    end

    # The static `Vow::ProcedureDescriptor` for this binding — its entry in the
    # manifest that mirrors the *current* wire contract: the dispatch `id` as the
    # procedure name, the resolved JS-facing arg names paired with their declared
    # Crystal type, and the return type. `optional` is always false (lune's
    # positional bindings carry no per-arg default info), and `verb` is the
    # neutral default since the webview transport has no HTTP-verb notion.
    def to_vow_descriptor : Vow::ProcedureDescriptor
      keys = arg_keys
      args = @args.map_with_index do |type, i|
        Vow::ArgDescriptor.new(keys[i], type, false)
      end
      Vow::ProcedureDescriptor.new(name: id, args: args, return_type: @return_type, verb: "post")
    end

    # The TS type of the single named-args object: `args: { camelKey: T; … }`,
    # or `args?: {}` for a zero-arg binding (so `fn()` stays callable).
    def dts_params(known : Hash(String, String) = {} of String => String)
      return "args?: {}" if @args.empty?
      keys = arg_keys
      fields = @args.each_with_index.map { |type, i|
        ts = @ts_args[i]? || Lune::Generator.crystal_to_ts(type, known)
        "#{keys[i]}: #{ts}"
      }
      "args: { #{fields.join("; ")} }"
    end

    def internal?
      @internal
    end

    protected def resolved_arg_names : Array(String)
      @arg_names.empty? ? Array(String).new(@args.size) { |i| "arg#{i}" } : @arg_names
    end
  end
end
