require "../spec_helper"

private def make_bd(method = "ping", namespace = "alpha", args = [] of String, return_type = "String")
  Lune::Binding.new(
    method: method,
    namespace: namespace,
    args: args,
    return_type: return_type,
    callback: ->(_a : Array(JSON::Any)) { JSON::Any.new("ok") }
  )
end

describe Lune::Binding do
  describe "#id" do
    it "combines namespace and name with a dot" do
      make_bd(method: "ping", namespace: "alpha").id.should eq("alpha.ping")
    end

    it "returns just the name when namespace is empty" do
      make_bd(method: "ping", namespace: "").id.should eq("ping")
    end

    it "joins nested Crystal namespaces with dots" do
      make_bd(method: "go", namespace: "alpha::beta").id.should eq("alpha.beta.go")
    end
  end

  describe "#js_func_name" do
    it "camelcases the binding name" do
      make_bd(method: "open_url").js_func_name.should eq("openUrl")
    end

    it "leaves an already-camel name untouched" do
      make_bd(method: "ping").js_func_name.should eq("ping")
    end
  end

  describe "#to_js_stub" do
    it "emits a JS function stub with the correct call ID" do
      stub = make_bd(method: "ping", namespace: "alpha").to_js_stub
      stub.includes?("ping()").should be_true
      stub.includes?(%("alpha.ping")).should be_true
      stub.includes?("return __lune.call(").should be_true
    end

    it "uses dot-joined id for nested namespaces" do
      stub = make_bd(method: "go", namespace: "alpha::beta").to_js_stub
      stub.includes?(%("alpha.beta.go")).should be_true
    end

    it "falls back to arg0..argN when arg_names is empty" do
      stub = make_bd(method: "add", namespace: "math", args: ["Int32", "String"]).to_js_stub
      stub.includes?("add(arg0, arg1)").should be_true
    end

    it "uses arg_names when provided" do
      bd = Lune::Binding.new(
        method: "add",
        namespace: "math",
        args: ["Int32", "String"],
        return_type: "Int32",
        callback: ->(_a : Array(JSON::Any)) { JSON::Any.new(0_i64) },
        arg_names: ["n", "label"]
      )
      bd.to_js_stub.includes?("add(n, label)").should be_true
    end
  end

  describe "#to_dts_sig" do
    it "emits a typed Promise signature with no params" do
      sig = make_bd(method: "ping", namespace: "alpha", return_type: "String").to_dts_sig
      sig.should eq("  ping(): Promise<string>;")
    end

    it "maps Crystal args to TypeScript parameter types using arg0..argN fallback" do
      sig = make_bd(method: "add", namespace: "math", args: ["Int32", "String"], return_type: "Int32").to_dts_sig
      sig.should eq("  add(arg0: number, arg1: string): Promise<number>;")
    end

    it "uses arg_names when provided" do
      bd = Lune::Binding.new(
        method: "add",
        namespace: "math",
        args: ["Int32", "String"],
        return_type: "Int32",
        callback: ->(_a : Array(JSON::Any)) { JSON::Any.new(0_i64) },
        arg_names: ["n", "label"]
      )
      bd.to_dts_sig.should eq("  add(n: number, label: string): Promise<number>;")
    end

    it "maps Nil return to void" do
      make_bd(method: "quit", namespace: "runtime", return_type: "Nil").to_dts_sig.includes?("Promise<void>").should be_true
    end
  end

  describe ".crystal_to_ts" do
    it "maps primitive Crystal types" do
      Lune::Runtime::Generator.crystal_to_ts("String").should eq("string")
      Lune::Runtime::Generator.crystal_to_ts("Bool").should eq("boolean")
      Lune::Runtime::Generator.crystal_to_ts("Nil").should eq("void")
      Lune::Runtime::Generator.crystal_to_ts("Int32").should eq("number")
      Lune::Runtime::Generator.crystal_to_ts("Int64").should eq("number")
      Lune::Runtime::Generator.crystal_to_ts("Float32").should eq("number")
      Lune::Runtime::Generator.crystal_to_ts("Float64").should eq("number")
    end

    it "maps collection types" do
      Lune::Runtime::Generator.crystal_to_ts("Array").should eq("any[]")
      Lune::Runtime::Generator.crystal_to_ts("Hash").should eq("Record<string, any>")
    end

    it "falls back to Record<string, any> for unknown types" do
      Lune::Runtime::Generator.crystal_to_ts("MyStruct").should eq("Record<string, any>")
    end
  end
end
