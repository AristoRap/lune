require "../../spec_helper"

describe Lune::Plugins::Kv do
  describe "descriptor" do
    it "has correct id and label" do
      d = Lune::Plugins::Kv::DESCRIPTOR
      d.id.should eq(:kv)
      d.label.should eq("Kv")
    end

    it "has no hard deps" do
      Lune::Plugins::Kv::DESCRIPTOR.deps.should be_empty
    end

    it "is not core" do
      Lune::Plugins::Kv::DESCRIPTOR.core.should be_false
    end
  end

  describe "name and namespace" do
    it "derives name from descriptor" do
      Lune::Plugins::Kv.new.name.should eq("kv")
    end

    it "has Kv binding namespace" do
      Lune::Plugins::Kv.new.binding_namespace.should eq("Kv")
    end
  end

  describe "phase membership" do
    it "includes Bindable" do
      Lune::Plugins::Kv.new.is_a?(Lune::Bindable).should be_true
    end

    it "includes Lifecycle" do
      Lune::Plugins::Kv.new.is_a?(Lune::Plugin::Lifecycle).should be_true
    end

    it "does not include WebviewInject" do
      Lune::Plugins::Kv.new.is_a?(Lune::Plugin::WebviewInject).should be_false
    end
  end

  describe "install" do
    it "registers get, set, delete, has, keys, and clear bindings" do
      cap = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(cap)
      ids = app.bindings.map(&.id)
      ids.should contain("Kv.get")
      ids.should contain("Kv.set")
      ids.should contain("Kv.delete")
      ids.should contain("Kv.has")
      ids.should contain("Kv.keys")
      ids.should contain("Kv.clear")
    end

    it "get returns nil for unknown key" do
      cap = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(cap)
      get_b = app.bindings.find { |b| b.id == "Kv.get" }.not_nil!
      result = get_b.callback.call([JSON::Any.new("missing")])
      result.raw.should be_nil
    end

    it "set then get returns the stored value" do
      cap = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(cap)
      set_b = app.bindings.find { |b| b.id == "Kv.set" }.not_nil!
      get_b = app.bindings.find { |b| b.id == "Kv.get" }.not_nil!
      set_b.callback.call([JSON::Any.new("name"), JSON::Any.new("alice")])
      result = get_b.callback.call([JSON::Any.new("name")])
      result.as_s.should eq("alice")
    end

    it "set accepts non-string values" do
      cap = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(cap)
      set_b = app.bindings.find { |b| b.id == "Kv.set" }.not_nil!
      get_b = app.bindings.find { |b| b.id == "Kv.get" }.not_nil!
      set_b.callback.call([JSON::Any.new("count"), JSON::Any.new(42_i64)])
      result = get_b.callback.call([JSON::Any.new("count")])
      result.as_i64.should eq(42)
    end

    it "has returns false for missing key" do
      cap = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(cap)
      has_b = app.bindings.find { |b| b.id == "Kv.has" }.not_nil!
      has_b.callback.call([JSON::Any.new("nope")]).as_bool.should be_false
    end

    it "has returns true after set" do
      cap = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(cap)
      set_b = app.bindings.find { |b| b.id == "Kv.set" }.not_nil!
      has_b = app.bindings.find { |b| b.id == "Kv.has" }.not_nil!
      set_b.callback.call([JSON::Any.new("x"), JSON::Any.new("y")])
      has_b.callback.call([JSON::Any.new("x")]).as_bool.should be_true
    end

    it "keys returns all set keys" do
      cap = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(cap)
      set_b = app.bindings.find { |b| b.id == "Kv.set" }.not_nil!
      keys_b = app.bindings.find { |b| b.id == "Kv.keys" }.not_nil!
      set_b.callback.call([JSON::Any.new("a"), JSON::Any.new("1")])
      set_b.callback.call([JSON::Any.new("b"), JSON::Any.new("2")])
      keys = keys_b.callback.call([] of JSON::Any).as_a.map(&.as_s)
      keys.should contain("a")
      keys.should contain("b")
    end

    it "delete removes a key" do
      cap = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(cap)
      set_b = app.bindings.find { |b| b.id == "Kv.set" }.not_nil!
      del_b = app.bindings.find { |b| b.id == "Kv.delete" }.not_nil!
      has_b = app.bindings.find { |b| b.id == "Kv.has" }.not_nil!
      set_b.callback.call([JSON::Any.new("tmp"), JSON::Any.new("val")])
      del_b.callback.call([JSON::Any.new("tmp")])
      has_b.callback.call([JSON::Any.new("tmp")]).as_bool.should be_false
    end

    it "clear empties the store" do
      cap = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(cap)
      set_b = app.bindings.find { |b| b.id == "Kv.set" }.not_nil!
      clear_b = app.bindings.find { |b| b.id == "Kv.clear" }.not_nil!
      keys_b = app.bindings.find { |b| b.id == "Kv.keys" }.not_nil!
      set_b.callback.call([JSON::Any.new("k1"), JSON::Any.new("v1")])
      set_b.callback.call([JSON::Any.new("k2"), JSON::Any.new("v2")])
      clear_b.callback.call([] of JSON::Any)
      keys_b.callback.call([] of JSON::Any).as_a.should be_empty
    end
  end

  describe "registry integration" do
    it "is included in the default resolved set" do
      r = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigPlugins.new(enabled: nil, disabled: nil))
      resolved.plugins.map(&.name).should contain("kv")
    end

    it "can be excluded" do
      r = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigPlugins.new(enabled: nil, disabled: ["kv"]))
      resolved.plugins.map(&.name).should_not contain("kv")
    end
  end

  describe "runtime.d.ts signatures" do
    it "emits keys() as Promise<string[]>" do
      cap = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(cap)
      dts = Lune::Generator.generate_runtime_dts(app.bindings, [cap] of Lune::Plugin)
      dts.should contain("keys(): Promise<string[]>")
    end

    it "emits has(key) as Promise<boolean>" do
      cap = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(cap)
      dts = Lune::Generator.generate_runtime_dts(app.bindings, [cap] of Lune::Plugin)
      dts.should contain("has(key: string): Promise<boolean>")
    end
  end
end
