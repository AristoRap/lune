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
      Lune::Plugins::Kv.new.binding_namespace.should eq("Lune::Plugins::Kv")
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
      plugin = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(plugin)
      ids = app.bindings.map(&.id)
      ids.should contain("Lune.Plugins.Kv.get")
      ids.should contain("Lune.Plugins.Kv.set")
      ids.should contain("Lune.Plugins.Kv.delete")
      ids.should contain("Lune.Plugins.Kv.has")
      ids.should contain("Lune.Plugins.Kv.keys")
      ids.should contain("Lune.Plugins.Kv.clear")
    end

    it "get returns nil for unknown key" do
      plugin = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(plugin)
      get_b = app.bindings.find { |b| b.id == "Lune.Plugins.Kv.get" }.not_nil!
      result = JSON.parse(app.registry.dispatch(get_b.id, ({"key" => JSON::Any.new("missing")}).to_json, nil))
      result.raw.should be_nil
    end

    it "set then get returns the stored value" do
      plugin = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(plugin)
      set_b = app.bindings.find { |b| b.id == "Lune.Plugins.Kv.set" }.not_nil!
      get_b = app.bindings.find { |b| b.id == "Lune.Plugins.Kv.get" }.not_nil!
      JSON.parse(app.registry.dispatch(set_b.id, ({"key" => JSON::Any.new("name"), "value" => JSON::Any.new("alice")}).to_json, nil))
      result = JSON.parse(app.registry.dispatch(get_b.id, ({"key" => JSON::Any.new("name")}).to_json, nil))
      result.as_s.should eq("alice")
    end

    it "set accepts non-string values" do
      plugin = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(plugin)
      set_b = app.bindings.find { |b| b.id == "Lune.Plugins.Kv.set" }.not_nil!
      get_b = app.bindings.find { |b| b.id == "Lune.Plugins.Kv.get" }.not_nil!
      JSON.parse(app.registry.dispatch(set_b.id, ({"key" => JSON::Any.new("count"), "value" => JSON::Any.new(42_i64)}).to_json, nil))
      result = JSON.parse(app.registry.dispatch(get_b.id, ({"key" => JSON::Any.new("count")}).to_json, nil))
      result.as_i64.should eq(42)
    end

    it "has returns false for missing key" do
      plugin = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(plugin)
      has_b = app.bindings.find { |b| b.id == "Lune.Plugins.Kv.has" }.not_nil!
      JSON.parse(app.registry.dispatch(has_b.id, ({"key" => JSON::Any.new("nope")}).to_json, nil)).as_bool.should be_false
    end

    it "has returns true after set" do
      plugin = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(plugin)
      set_b = app.bindings.find { |b| b.id == "Lune.Plugins.Kv.set" }.not_nil!
      has_b = app.bindings.find { |b| b.id == "Lune.Plugins.Kv.has" }.not_nil!
      JSON.parse(app.registry.dispatch(set_b.id, ({"key" => JSON::Any.new("x"), "value" => JSON::Any.new("y")}).to_json, nil))
      JSON.parse(app.registry.dispatch(has_b.id, ({"key" => JSON::Any.new("x")}).to_json, nil)).as_bool.should be_true
    end

    it "keys returns all set keys" do
      plugin = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(plugin)
      set_b = app.bindings.find { |b| b.id == "Lune.Plugins.Kv.set" }.not_nil!
      keys_b = app.bindings.find { |b| b.id == "Lune.Plugins.Kv.keys" }.not_nil!
      JSON.parse(app.registry.dispatch(set_b.id, ({"key" => JSON::Any.new("a"), "value" => JSON::Any.new("1")}).to_json, nil))
      JSON.parse(app.registry.dispatch(set_b.id, ({"key" => JSON::Any.new("b"), "value" => JSON::Any.new("2")}).to_json, nil))
      keys = JSON.parse(app.registry.dispatch(keys_b.id, ({} of String => JSON::Any).to_json, nil)).as_a.map(&.as_s)
      keys.should contain("a")
      keys.should contain("b")
    end

    it "delete removes a key" do
      plugin = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(plugin)
      set_b = app.bindings.find { |b| b.id == "Lune.Plugins.Kv.set" }.not_nil!
      del_b = app.bindings.find { |b| b.id == "Lune.Plugins.Kv.delete" }.not_nil!
      has_b = app.bindings.find { |b| b.id == "Lune.Plugins.Kv.has" }.not_nil!
      JSON.parse(app.registry.dispatch(set_b.id, ({"key" => JSON::Any.new("tmp"), "value" => JSON::Any.new("val")}).to_json, nil))
      JSON.parse(app.registry.dispatch(del_b.id, ({"key" => JSON::Any.new("tmp")}).to_json, nil))
      JSON.parse(app.registry.dispatch(has_b.id, ({"key" => JSON::Any.new("tmp")}).to_json, nil)).as_bool.should be_false
    end

    it "clear empties the store" do
      plugin = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(plugin)
      set_b = app.bindings.find { |b| b.id == "Lune.Plugins.Kv.set" }.not_nil!
      clear_b = app.bindings.find { |b| b.id == "Lune.Plugins.Kv.clear" }.not_nil!
      keys_b = app.bindings.find { |b| b.id == "Lune.Plugins.Kv.keys" }.not_nil!
      JSON.parse(app.registry.dispatch(set_b.id, ({"key" => JSON::Any.new("k1"), "value" => JSON::Any.new("v1")}).to_json, nil))
      JSON.parse(app.registry.dispatch(set_b.id, ({"key" => JSON::Any.new("k2"), "value" => JSON::Any.new("v2")}).to_json, nil))
      JSON.parse(app.registry.dispatch(clear_b.id, ({} of String => JSON::Any).to_json, nil))
      JSON.parse(app.registry.dispatch(keys_b.id, ({} of String => JSON::Any).to_json, nil)).as_a.should be_empty
    end
  end

  describe "registry integration" do
    it "is included in the default resolved set" do
      r = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::Config::Plugins.new(enabled: nil, disabled: nil))
      resolved.plugins.map(&.name).should contain("kv")
    end

    it "can be excluded" do
      r = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::Config::Plugins.new(enabled: nil, disabled: ["kv"]))
      resolved.plugins.map(&.name).should_not contain("kv")
    end
  end

  describe "runtime.d.ts signatures" do
    it "emits keys() as Promise<string[]>" do
      plugin = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(plugin)
      dts = Lune::Generator.generate_runtime_dts(app.bindings, [plugin] of Lune::Plugin)
      dts.should contain("keys(args?: {}): Promise<string[]>")
    end

    it "emits has(key) as Promise<boolean>" do
      plugin = Lune::Plugins::Kv.new
      app = Lune::App.new
      app.install(plugin)
      dts = Lune::Generator.generate_runtime_dts(app.bindings, [plugin] of Lune::Plugin)
      dts.should contain("has(args: { key: string }): Promise<boolean>")
    end
  end
end
