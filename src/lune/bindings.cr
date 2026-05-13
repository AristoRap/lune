module Lune
  record BindingDef,
    name : String,
    namespace : String,
    args : Array(String),
    return_type : String,
    callback : Proc(Array(JSON::Any), JSON::Any),
    internal : Bool = false,
    async : Bool = false

  def self.binding_id(namespace : String, name : String) : String
    return name if namespace.empty?
    ns = namespace
      .split("::")
      .join(".")

    "#{ns}.#{name}"
  end
end
