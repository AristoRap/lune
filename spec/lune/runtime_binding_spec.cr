require "../spec_helper"

private def make_rb(method = "__lune.ping", args = [] of String, return_type = "String", arg_names = [] of String, ts_return_type = nil)
  Lune::RuntimeBinding.new(
    namespace: "runtime",
    method: method,
    args: args,
    return_type: return_type,
    callback: ->(_a : Array(JSON::Any)) { JSON::Any.new("ok") },
    arg_names: arg_names,
    ts_return_type: ts_return_type
  )
end

describe Lune::RuntimeBinding do
  describe "#js_func_name" do
    it "strips the __lune. prefix" do
      make_rb(method: "__lune.quit").js_func_name.should eq("quit")
      make_rb(method: "__lune.openURL").js_func_name.should eq("openURL")
      make_rb(method: "__lune.screenInfo").js_func_name.should eq("screenInfo")
    end
  end

  describe "#internal?" do
    it "is always true" do
      make_rb.internal?.should be_true
    end
  end

  describe "#to_js_stub" do
    it "emits an export function with no args" do
      stub = make_rb(method: "__lune.quit").to_js_stub
      stub.should eq(%(export function quit() { return __lune.call("runtime.__lune.quit"); }))
    end

    it "emits an export function with named args" do
      stub = make_rb(method: "__lune.openURL", args: ["String"], arg_names: ["url"]).to_js_stub
      stub.should eq(%(export function openURL(url) { return __lune.call("runtime.__lune.openURL", url); }))
    end

    it "falls back to arg0..argN when arg_names is empty" do
      stub = make_rb(method: "__lune.setSize", args: ["Int32", "Int32"]).to_js_stub
      stub.includes?("arg0, arg1").should be_true
    end
  end

  describe "#to_dts_sig" do
    it "emits an export declare function wrapping return in Promise" do
      sig = make_rb(method: "__lune.homeDir", return_type: "String").to_dts_sig
      sig.should eq("export declare function homeDir(): Promise<string>;")
    end

    it "uses ts_return_type as the full return type bypassing auto-wrap" do
      sig = make_rb(method: "__lune.environment", return_type: "JSON", ts_return_type: "LuneEnvironment").to_dts_sig
      sig.should eq("export declare function environment(): LuneEnvironment;")
    end

    it "uses ts_return_type with explicit Promise when needed" do
      sig = make_rb(method: "__lune.screenInfo", return_type: "String", ts_return_type: "Promise<ScreenInfo>").to_dts_sig
      sig.should eq("export declare function screenInfo(): Promise<ScreenInfo>;")
    end

    it "includes named params in the signature" do
      sig = make_rb(method: "__lune.notify", args: ["String", "String"], return_type: "Nil", arg_names: ["title", "body"]).to_dts_sig
      sig.should eq("export declare function notify(title: string, body: string): Promise<void>;")
    end
  end
end
