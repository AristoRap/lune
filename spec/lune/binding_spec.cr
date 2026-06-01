require "../spec_helper"

private def make_bd(method = "ping", namespace = "alpha", args = [] of String, return_type = "String")
  Lune::Binding.new(
    method: method,
    namespace: namespace,
    args: args,
    return_type: return_type
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
      stub.includes?("ping(args = {})").should be_true
      stub.includes?(%("alpha.ping")).should be_true
      stub.includes?("return __lune.call(").should be_true
    end

    it "uses dot-joined id for nested namespaces" do
      stub = make_bd(method: "go", namespace: "alpha::beta").to_js_stub
      stub.includes?(%("alpha.beta.go")).should be_true
    end

    it "forwards the single named-args object regardless of arity" do
      stub = make_bd(method: "add", namespace: "math", args: ["Int32", "String"]).to_js_stub
      stub.includes?("add(args)").should be_true
    end

    it "forwards the named-args object when arg_names are provided" do
      bd = Lune::Binding.new(
        method: "add",
        namespace: "math",
        args: ["Int32", "String"],
        return_type: "Int32",
        arg_names: ["n", "label"]
      )
      bd.to_js_stub.includes?("add(args)").should be_true
    end
  end

  describe "#to_dts_sig" do
    it "emits a typed Promise signature with an optional empty args object" do
      sig = make_bd(method: "ping", namespace: "alpha", return_type: "String").to_dts_sig
      sig.should eq("  ping(args?: {}): Promise<string>;")
    end

    it "maps Crystal args to a typed named-args object using arg0..argN fallback keys" do
      sig = make_bd(method: "add", namespace: "math", args: ["Int32", "String"], return_type: "Int32").to_dts_sig
      sig.should eq("  add(args: { arg0: number; arg1: string }): Promise<number>;")
    end

    it "uses arg_names as the named-args object keys when provided" do
      bd = Lune::Binding.new(
        method: "add",
        namespace: "math",
        args: ["Int32", "String"],
        return_type: "Int32",
        arg_names: ["n", "label"]
      )
      bd.to_dts_sig.should eq("  add(args: { n: number; label: string }): Promise<number>;")
    end

    it "maps Nil return to void" do
      make_bd(method: "quit", namespace: "runtime", return_type: "Nil").to_dts_sig.includes?("Promise<void>").should be_true
    end
  end

  # Type mapping is delegated to vow's strict `Vow::Codegen.crystal_to_ts`
  # (arg position) and `return_to_ts` (return position). vow RAISES on a type it
  # can't map honestly rather than silently widening it to `Record<string, any>`,
  # and it understands unions, `Set`, `Char`, and `JSON::Any`.
  describe ".crystal_to_ts" do
    it "maps primitive Crystal types" do
      Lune::Generator.crystal_to_ts("String").should eq("string")
      Lune::Generator.crystal_to_ts("Bool").should eq("boolean")
      Lune::Generator.crystal_to_ts("Char").should eq("string")
      Lune::Generator.crystal_to_ts("Int32").should eq("number")
      Lune::Generator.crystal_to_ts("Int64").should eq("number")
      Lune::Generator.crystal_to_ts("Float32").should eq("number")
      Lune::Generator.crystal_to_ts("Float64").should eq("number")
    end

    it "maps JSON::Any to any (not Record<string, any>)" do
      Lune::Generator.crystal_to_ts("JSON::Any").should eq("any")
    end

    # `Nil` is the one type whose mapping depends on position: a `Nil` argument
    # is `null`, but a `Nil` return is `void` (`Promise<void>`).
    it "maps Nil to null in argument position and void in return position" do
      Lune::Generator.crystal_to_ts("Nil").should eq("null")
      Lune::Generator.crystal_return_to_ts("Nil").should eq("void")
    end

    it "maps parameterized Array to a typed TS array" do
      Lune::Generator.crystal_to_ts("Array(String)").should eq("string[]")
      Lune::Generator.crystal_to_ts("Array(Int32)").should eq("number[]")
      Lune::Generator.crystal_to_ts("Array(Bool)").should eq("boolean[]")
    end

    it "maps Set to a TS array" do
      Lune::Generator.crystal_to_ts("Set(String)").should eq("string[]")
    end

    it "maps parameterized Hash to Record<K, V>" do
      Lune::Generator.crystal_to_ts("Hash(String, Int32)").should eq("Record<string, number>")
      Lune::Generator.crystal_to_ts("Hash(String, Bool)").should eq("Record<string, boolean>")
    end

    it "maps Tuple to TS tuple syntax" do
      Lune::Generator.crystal_to_ts("Tuple(String, Int32)").should eq("[string, number]")
      Lune::Generator.crystal_to_ts("Tuple(String, Int32, Bool)").should eq("[string, number, boolean]")
    end

    it "maps unions, mapping Nil to null" do
      Lune::Generator.crystal_to_ts("(String | Nil)").should eq("string | null")
      Lune::Generator.crystal_to_ts("Int32 | String").should eq("number | string")
    end

    it "recurses through nested generics" do
      Lune::Generator.crystal_to_ts("Array(Array(String))").should eq("string[][]")
      Lune::Generator.crystal_to_ts("Hash(String, Array(Int32))").should eq("Record<string, number[]>")
      Lune::Generator.crystal_to_ts("Array(Hash(String, Bool))").should eq("Record<string, boolean>[]")
    end

    it "tolerates whitespace inside generics" do
      Lune::Generator.crystal_to_ts("Array( String )").should eq("string[]")
      Lune::Generator.crystal_to_ts("Hash( String , Int32 )").should eq("Record<string, number>")
    end

    it "raises on an unmapped identifier instead of widening to Record<string, any>" do
      expect_raises(Vow::Codegen::UnmappableType) do
        Lune::Generator.crystal_to_ts("MyStruct")
      end
    end

    it "raises on an unmapped inner generic type" do
      expect_raises(Vow::Codegen::UnmappableType) do
        Lune::Generator.crystal_to_ts("Array(MyStruct)")
      end
    end

    it "raises on bare collection types with no element type" do
      expect_raises(Vow::Codegen::UnmappableType) { Lune::Generator.crystal_to_ts("Array") }
      expect_raises(Vow::Codegen::UnmappableType) { Lune::Generator.crystal_to_ts("Hash") }
      expect_raises(Vow::Codegen::UnmappableType) { Lune::Generator.crystal_to_ts("NamedTuple") }
    end

    it "supports extended integer / unsigned int primitives" do
      Lune::Generator.crystal_to_ts("Int8").should eq("number")
      Lune::Generator.crystal_to_ts("Int16").should eq("number")
      Lune::Generator.crystal_to_ts("UInt32").should eq("number")
      Lune::Generator.crystal_to_ts("UInt64").should eq("number")
    end

    it "maps parameterized NamedTuple to a structural TS object" do
      Lune::Generator.crystal_to_ts("NamedTuple(width: Int32, height: Int32, scale: Float64)")
        .should eq("{ width: number; height: number; scale: number }")
    end

    it "maps single-field NamedTuple" do
      Lune::Generator.crystal_to_ts("NamedTuple(name: String)")
        .should eq("{ name: string }")
    end

    it "recurses through NamedTuple field types" do
      Lune::Generator.crystal_to_ts("NamedTuple(point: Tuple(Int32, Int32), label: String)")
        .should eq("{ point: [number, number]; label: string }")
      Lune::Generator.crystal_to_ts("NamedTuple(tags: Array(String), counts: Hash(String, Int32))")
        .should eq("{ tags: string[]; counts: Record<string, number> }")
    end

    it "tolerates whitespace inside NamedTuple field specs" do
      Lune::Generator.crystal_to_ts("NamedTuple( width : Int32 , height : Int32 )")
        .should eq("{ width: number; height: number }")
    end
  end
end
