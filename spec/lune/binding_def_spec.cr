require "../spec_helper"

private def make_bd(name = "ping", namespace = "alpha", args = [] of String, return_type = "String")
  Lune::BindingDef.new(
    name: name,
    namespace: namespace,
    args: args,
    return_type: return_type,
    callback: ->(_a : Array(JSON::Any)) { JSON::Any.new("ok") }
  )
end

describe Lune::BindingDef do
  describe "#id" do
    it "combines namespace and name with a dot" do
      make_bd(name: "ping", namespace: "alpha").id.should eq("alpha.ping")
    end

    it "returns just the name when namespace is empty" do
      make_bd(name: "ping", namespace: "").id.should eq("ping")
    end

    it "joins nested Crystal namespaces with dots" do
      make_bd(name: "go", namespace: "alpha::beta").id.should eq("alpha.beta.go")
    end
  end

  describe "#js_fn_name" do
    it "camelcases the binding name" do
      make_bd(name: "open_url").js_fn_name.should eq("OpenUrl")
    end

    it "leaves an already-camel name untouched" do
      make_bd(name: "ping").js_fn_name.should eq("Ping")
    end
  end

  describe "#to_js_stub" do
    it "emits a JS function stub with the correct call ID" do
      stub = make_bd(name: "ping", namespace: "alpha").to_js_stub
      stub.includes?("Ping(...args)").should be_true
      stub.includes?(%("alpha.ping")).should be_true
      stub.includes?("return __lune.call(").should be_true
    end

    it "uses dot-joined id for nested namespaces" do
      stub = make_bd(name: "go", namespace: "alpha::beta").to_js_stub
      stub.includes?(%("alpha.beta.go")).should be_true
    end
  end

  describe "#to_dts_sig" do
    it "emits a typed Promise signature with no params" do
      sig = make_bd(name: "ping", namespace: "alpha", return_type: "String").to_dts_sig
      sig.should eq("  Ping(): Promise<string>;")
    end

    it "maps Crystal args to TypeScript parameter types" do
      sig = make_bd(name: "add", namespace: "math", args: ["Int32", "String"], return_type: "Int32").to_dts_sig
      sig.should eq("  Add(arg0: number, arg1: string): Promise<number>;")
    end

    it "maps Nil return to void" do
      make_bd(name: "quit", namespace: "runtime", return_type: "Nil").to_dts_sig.includes?("Promise<void>").should be_true
    end
  end

  describe ".crystal_to_ts" do
    it "maps primitive Crystal types" do
      Lune::BindingDef.crystal_to_ts("String").should eq("string")
      Lune::BindingDef.crystal_to_ts("Bool").should eq("boolean")
      Lune::BindingDef.crystal_to_ts("Nil").should eq("void")
      Lune::BindingDef.crystal_to_ts("Int32").should eq("number")
      Lune::BindingDef.crystal_to_ts("Int64").should eq("number")
      Lune::BindingDef.crystal_to_ts("Float32").should eq("number")
      Lune::BindingDef.crystal_to_ts("Float64").should eq("number")
    end

    it "maps collection types" do
      Lune::BindingDef.crystal_to_ts("Array").should eq("any[]")
      Lune::BindingDef.crystal_to_ts("Hash").should eq("Record<string, any>")
    end

    it "falls back to Record<string, any> for unknown types" do
      Lune::BindingDef.crystal_to_ts("MyStruct").should eq("Record<string, any>")
    end
  end
end
