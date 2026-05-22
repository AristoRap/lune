require "../spec_helper"

# `internal: true` Bindings model the runtime-side JS surface: id is rooted
# at BRIDGE_MARKER, the JS func name is the camelcased leaf (last `.`-segment
# of `method`), and the stub formatting matches `runtime.js`.
private def make_internal(method = "test.ping", namespace = "Test", args = [] of String, return_type = "String", arg_names = [] of String, ts_return_type = nil)
  Lune::Binding.new(
    namespace: namespace,
    method: method,
    args: args,
    return_type: return_type,
    callback: ->(_a : Array(JSON::Any)) { JSON::Any.new("ok") },
    internal: true,
    arg_names: arg_names,
    ts_return_type: ts_return_type,
  )
end

describe "Lune::Binding (internal: true — runtime surface)" do
  describe "#id" do
    it "puts BRIDGE_MARKER at root: __lune.<plugin>.<method>" do
      make_internal(method: "system.quit").id.should eq("__lune.system.quit")
      make_internal(method: "clipboard.read").id.should eq("__lune.clipboard.read")
      make_internal(method: "screen.info").id.should eq("__lune.screen.info")
    end
  end

  describe "#js_func_name" do
    it "returns the camelCase leaf (last path segment)" do
      make_internal(method: "system.quit").js_func_name.should eq("quit")
      make_internal(method: "system.openURL").js_func_name.should eq("openURL")
      make_internal(method: "screen.info").js_func_name.should eq("info")
    end
  end

  describe "#internal?" do
    it "is true" do
      make_internal.internal?.should be_true
    end
  end

  describe "#to_js_stub" do
    it "emits an object method calling the correct bridge ID" do
      stub = make_internal(method: "system.quit", namespace: "System").to_js_stub
      stub.should eq(%(  quit() { return __lune.call("__lune.system.quit"); },))
    end

    it "emits an object method with named args" do
      stub = make_internal(method: "system.openURL", namespace: "System", args: ["String"], arg_names: ["url"]).to_js_stub
      stub.should eq(%(  openURL(url) { return __lune.call("__lune.system.openURL", url); },))
    end

    it "falls back to arg0..argN when arg_names is empty" do
      stub = make_internal(method: "window.setSize", args: ["Int32", "Int32"]).to_js_stub
      stub.includes?("arg0, arg1").should be_true
    end
  end

  describe "#to_dts_sig" do
    it "emits an interface member wrapping return in Promise" do
      sig = make_internal(method: "filesystem.homeDir", return_type: "String").to_dts_sig
      sig.should eq("  homeDir(): Promise<string>;")
    end

    it "uses ts_return_type as the full return type bypassing auto-wrap" do
      sig = make_internal(method: "system.environment", return_type: "JSON", ts_return_type: "LuneEnvironment").to_dts_sig
      sig.should eq("  environment(): LuneEnvironment;")
    end

    it "uses ts_return_type with explicit Promise when needed" do
      sig = make_internal(method: "screen.info", return_type: "String", ts_return_type: "Promise<ScreenInfo>").to_dts_sig
      sig.should eq("  info(): Promise<ScreenInfo>;")
    end

    it "includes named params in the signature" do
      sig = make_internal(method: "notifications.notify", args: ["String", "String"], return_type: "Nil", arg_names: ["title", "body"]).to_dts_sig
      sig.should eq("  notify(title: string, body: string): Promise<void>;")
    end
  end
end
