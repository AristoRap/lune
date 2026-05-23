require "../spec_helper"

# `internal: true` plugin bindings produce the same id/js_func_name/stub shape
# as user bindings (`<Namespace>.<method>`). The flag only decides where the
# Generator emits the stub — `plugins/<id>.js` (internal) vs `app/App.js`
# (user). See section 0b of .claude/plugin-system.md.
private def make_internal(method = "ping", namespace = "Test", args = [] of String, return_type = "String", arg_names = [] of String, ts_return_type = nil)
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

describe "Lune::Binding (internal: true — plugin surface)" do
  describe "#id" do
    it "uses <Namespace>.<method> — same shape as user bindings" do
      make_internal(namespace: "Lune::Plugins::System", method: "quit").id.should eq("Lune.Plugins.System.quit")
      make_internal(namespace: "Lune::Plugins::Clipboard", method: "read").id.should eq("Lune.Plugins.Clipboard.read")
      make_internal(namespace: "Lune::Plugins::System", method: "screen_info").id.should eq("Lune.Plugins.System.screen_info")
    end
  end

  describe "#js_func_name" do
    it "camelCases the method (matches user-binding behavior)" do
      make_internal(method: "open_url").js_func_name.should eq("openUrl")
      make_internal(method: "info").js_func_name.should eq("info")
      make_internal(method: "set_size").js_func_name.should eq("setSize")
    end
  end

  describe "#internal?" do
    it "is true" do
      make_internal.internal?.should be_true
    end
  end

  describe "#to_js_stub" do
    it "emits a stub calling the unified <Namespace>.<method> bridge ID" do
      stub = make_internal(namespace: "Lune::Plugins::System", method: "quit").to_js_stub
      stub.includes?(%("Lune.Plugins.System.quit")).should be_true
      stub.includes?("quit()").should be_true
    end

    it "emits an object method with named args" do
      stub = make_internal(namespace: "Lune::Plugins::System", method: "open_url", args: ["String"], arg_names: ["url"]).to_js_stub
      stub.includes?("openUrl(url)").should be_true
      stub.includes?(%("Lune.Plugins.System.open_url", url)).should be_true
    end

    it "falls back to arg0..argN when arg_names is empty" do
      stub = make_internal(namespace: "Lune::Plugins::Window", method: "set_size", args: ["Int32", "Int32"]).to_js_stub
      stub.includes?("setSize(arg0, arg1)").should be_true
    end
  end

  describe "#to_dts_sig" do
    it "emits an interface member wrapping return in Promise" do
      sig = make_internal(namespace: "Lune::Plugins::Filesystem", method: "home_dir", return_type: "String").to_dts_sig
      sig.should eq("  homeDir(): Promise<string>;")
    end

    it "uses ts_return_type as the full return type bypassing auto-wrap" do
      sig = make_internal(namespace: "Lune::Plugins::System", method: "environment", return_type: "JSON", ts_return_type: "LuneEnvironment").to_dts_sig
      sig.should eq("  environment(): LuneEnvironment;")
    end

    it "uses ts_return_type with explicit Promise when needed" do
      sig = make_internal(namespace: "Lune::Plugins::System", method: "screen_info", return_type: "String", ts_return_type: "Promise<ScreenInfo>").to_dts_sig
      sig.should eq("  screenInfo(): Promise<ScreenInfo>;")
    end

    it "includes named params in the signature" do
      sig = make_internal(namespace: "Lune::Plugins::System", method: "notify", args: ["String", "String"], return_type: "Nil", arg_names: ["title", "body"]).to_dts_sig
      sig.should eq("  notify(title: string, body: string): Promise<void>;")
    end
  end
end
