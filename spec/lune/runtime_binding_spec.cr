require "../spec_helper"

# method is the capability-prefixed path, e.g. "lifecycle.quit" — no BRIDGE_MARKER prefix.
# The bridge ID is BRIDGE_MARKER + "." + method = "__lune.lifecycle.quit".
private def make_rb(method = "test.ping", js_namespace = "Test", args = [] of String, return_type = "String", arg_names = [] of String, ts_return_type = nil)
  Lune::RuntimeBinding.new(
    js_namespace: js_namespace,
    method: method,
    args: args,
    return_type: return_type,
    callback: ->(_a : Array(JSON::Any)) { JSON::Any.new("ok") },
    arg_names: arg_names,
    ts_return_type: ts_return_type
  )
end

describe Lune::RuntimeBinding do
  describe "#id" do
    it "puts BRIDGE_MARKER at root: __lune.<capability>.<method>" do
      make_rb(method: "lifecycle.quit").id.should eq("__lune.lifecycle.quit")
      make_rb(method: "clipboard.read").id.should eq("__lune.clipboard.read")
      make_rb(method: "screen.info").id.should eq("__lune.screen.info")
    end
  end

  describe "#js_func_name" do
    it "returns the camelCase leaf (last path segment)" do
      make_rb(method: "lifecycle.quit").js_func_name.should eq("quit")
      make_rb(method: "lifecycle.openURL").js_func_name.should eq("openURL")
      make_rb(method: "screen.info").js_func_name.should eq("info")
    end
  end

  describe "#internal?" do
    it "is always true" do
      make_rb.internal?.should be_true
    end
  end

  describe "#to_js_stub" do
    it "emits an object method calling the correct bridge ID" do
      stub = make_rb(method: "lifecycle.quit", js_namespace: "Lifecycle").to_js_stub
      stub.should eq(%(  quit() { return __lune.call("__lune.lifecycle.quit"); },))
    end

    it "emits an object method with named args" do
      stub = make_rb(method: "lifecycle.openURL", js_namespace: "Lifecycle", args: ["String"], arg_names: ["url"]).to_js_stub
      stub.should eq(%(  openURL(url) { return __lune.call("__lune.lifecycle.openURL", url); },))
    end

    it "falls back to arg0..argN when arg_names is empty" do
      stub = make_rb(method: "window.setSize", args: ["Int32", "Int32"]).to_js_stub
      stub.includes?("arg0, arg1").should be_true
    end
  end

  describe "#to_dts_sig" do
    it "emits an interface member wrapping return in Promise" do
      sig = make_rb(method: "filesystem.homeDir", return_type: "String").to_dts_sig
      sig.should eq("  homeDir(): Promise<string>;")
    end

    it "uses ts_return_type as the full return type bypassing auto-wrap" do
      sig = make_rb(method: "lifecycle.environment", return_type: "JSON", ts_return_type: "LuneEnvironment").to_dts_sig
      sig.should eq("  environment(): LuneEnvironment;")
    end

    it "uses ts_return_type with explicit Promise when needed" do
      sig = make_rb(method: "screen.info", return_type: "String", ts_return_type: "Promise<ScreenInfo>").to_dts_sig
      sig.should eq("  info(): Promise<ScreenInfo>;")
    end

    it "includes named params in the signature" do
      sig = make_rb(method: "notifications.notify", args: ["String", "String"], return_type: "Nil", arg_names: ["title", "body"]).to_dts_sig
      sig.should eq("  notify(title: string, body: string): Promise<void>;")
    end
  end
end
