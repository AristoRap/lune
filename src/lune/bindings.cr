module Lune
  record BindingDef,
    name : String,
    namespace : String,
    args : Array(String),
    return_type : String,
    callback : Proc(Array(JSON::Any), JSON::Any),
    internal : Bool = false,
    async : Bool = false do

    def id : String
      return name if namespace.empty?
      "#{namespace.split("::").join(".")}.#{name}"
    end

    def js_fn_name : String
      name.camelcase
    end

    def to_js_stub : String
      "  #{js_fn_name}(...args) {\n    return __lune.call(#{id.inspect}, ...args);\n  },"
    end

    def to_dts_sig : String
      ret = BindingDef.crystal_to_ts(return_type)
      params = args.each_with_index.map { |t, i| "arg#{i}: #{BindingDef.crystal_to_ts(t)}" }.join(", ")
      "  #{js_fn_name}(#{params}): Promise<#{ret}>;"
    end

    def self.crystal_to_ts(type : String) : String
      case type
      when "String"                                    then "string"
      when "Bool"                                      then "boolean"
      when "Nil"                                       then "void"
      when "Int32", "Int64", "Float32", "Float64"      then "number"
      when "Array"                                     then "any[]"
      when "Hash"                                      then "Record<string, any>"
      else                                                  "Record<string, any>"
      end
    end
  end
end
