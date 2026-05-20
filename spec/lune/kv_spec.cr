require "../spec_helper"

describe Lune::Capabilities::Kv do
  describe "descriptor" do
    it "has correct id and label" do
      d = Lune::Capabilities::Kv::DESCRIPTOR
      d.id.should eq(:kv)
      d.label.should eq("Kv")
    end

    it "has no hard deps" do
      Lune::Capabilities::Kv::DESCRIPTOR.deps.should be_empty
    end

    it "is not core" do
      Lune::Capabilities::Kv::DESCRIPTOR.core.should be_false
    end
  end

  describe "name and namespace" do
    it "derives name from descriptor" do
      Lune::Capabilities::Kv.new.name.should eq("kv")
    end

    it "has Kv binding namespace" do
      Lune::Capabilities::Kv.new.binding_namespace.should eq("Kv")
    end
  end

  describe "phase membership" do
    it "includes Bindable" do
      Lune::Capabilities::Kv.new.is_a?(Lune::Capability::Bindable).should be_true
    end

    it "includes Lifecycle" do
      Lune::Capabilities::Kv.new.is_a?(Lune::Capability::Lifecycle).should be_true
    end

    it "does not include WebviewInject" do
      Lune::Capabilities::Kv.new.is_a?(Lune::Capability::WebviewInject).should be_false
    end
  end

  describe "install" do
    it "registers get, set, delete, has, keys, and clear bindings" do
      cap = Lune::Capabilities::Kv.new
      app = Lune::App.new
      app.install(cap)
      ids = app.bindings.map(&.id)
      ids.should contain("__lune.kv.get")
      ids.should contain("__lune.kv.set")
      ids.should contain("__lune.kv.delete")
      ids.should contain("__lune.kv.has")
      ids.should contain("__lune.kv.keys")
      ids.should contain("__lune.kv.clear")
    end

    it "get returns nil for unknown key" do
      cap = Lune::Capabilities::Kv.new
      app = Lune::App.new
      app.install(cap)
      get_b = app.bindings.find { |b| b.id == "__lune.kv.get" }.not_nil!
      result = get_b.callback.call([JSON::Any.new("missing")])
      result.raw.should be_nil
    end

    it "set then get returns the stored value" do
      cap = Lune::Capabilities::Kv.new
      app = Lune::App.new
      app.install(cap)
      set_b = app.bindings.find { |b| b.id == "__lune.kv.set" }.not_nil!
      get_b = app.bindings.find { |b| b.id == "__lune.kv.get" }.not_nil!
      set_b.callback.call([JSON::Any.new("name"), JSON::Any.new("alice")])
      result = get_b.callback.call([JSON::Any.new("name")])
      result.as_s.should eq("alice")
    end

    it "set accepts non-string values" do
      cap = Lune::Capabilities::Kv.new
      app = Lune::App.new
      app.install(cap)
      set_b = app.bindings.find { |b| b.id == "__lune.kv.set" }.not_nil!
      get_b = app.bindings.find { |b| b.id == "__lune.kv.get" }.not_nil!
      set_b.callback.call([JSON::Any.new("count"), JSON::Any.new(42_i64)])
      result = get_b.callback.call([JSON::Any.new("count")])
      result.as_i64.should eq(42)
    end

    it "has returns false for missing key" do
      cap = Lune::Capabilities::Kv.new
      app = Lune::App.new
      app.install(cap)
      has_b = app.bindings.find { |b| b.id == "__lune.kv.has" }.not_nil!
      has_b.callback.call([JSON::Any.new("nope")]).as_bool.should be_false
    end

    it "has returns true after set" do
      cap = Lune::Capabilities::Kv.new
      app = Lune::App.new
      app.install(cap)
      set_b = app.bindings.find { |b| b.id == "__lune.kv.set" }.not_nil!
      has_b = app.bindings.find { |b| b.id == "__lune.kv.has" }.not_nil!
      set_b.callback.call([JSON::Any.new("x"), JSON::Any.new("y")])
      has_b.callback.call([JSON::Any.new("x")]).as_bool.should be_true
    end

    it "keys returns all set keys" do
      cap = Lune::Capabilities::Kv.new
      app = Lune::App.new
      app.install(cap)
      set_b = app.bindings.find { |b| b.id == "__lune.kv.set" }.not_nil!
      keys_b = app.bindings.find { |b| b.id == "__lune.kv.keys" }.not_nil!
      set_b.callback.call([JSON::Any.new("a"), JSON::Any.new("1")])
      set_b.callback.call([JSON::Any.new("b"), JSON::Any.new("2")])
      keys = keys_b.callback.call([] of JSON::Any).as_a.map(&.as_s)
      keys.should contain("a")
      keys.should contain("b")
    end

    it "delete removes a key" do
      cap = Lune::Capabilities::Kv.new
      app = Lune::App.new
      app.install(cap)
      set_b  = app.bindings.find { |b| b.id == "__lune.kv.set" }.not_nil!
      del_b  = app.bindings.find { |b| b.id == "__lune.kv.delete" }.not_nil!
      has_b  = app.bindings.find { |b| b.id == "__lune.kv.has" }.not_nil!
      set_b.callback.call([JSON::Any.new("tmp"), JSON::Any.new("val")])
      del_b.callback.call([JSON::Any.new("tmp")])
      has_b.callback.call([JSON::Any.new("tmp")]).as_bool.should be_false
    end

    it "clear empties the store" do
      cap = Lune::Capabilities::Kv.new
      app = Lune::App.new
      app.install(cap)
      set_b   = app.bindings.find { |b| b.id == "__lune.kv.set" }.not_nil!
      clear_b = app.bindings.find { |b| b.id == "__lune.kv.clear" }.not_nil!
      keys_b  = app.bindings.find { |b| b.id == "__lune.kv.keys" }.not_nil!
      set_b.callback.call([JSON::Any.new("k1"), JSON::Any.new("v1")])
      set_b.callback.call([JSON::Any.new("k2"), JSON::Any.new("v2")])
      clear_b.callback.call([] of JSON::Any)
      keys_b.callback.call([] of JSON::Any).as_a.should be_empty
    end
  end

  describe "registry integration" do
    it "is included in the default resolved set" do
      r = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigCapabilities.new(only: nil, exclude: nil))
      resolved.capabilities.map(&.name).should contain("kv")
    end

    it "can be excluded" do
      r = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigCapabilities.new(only: nil, exclude: ["kv"]))
      resolved.capabilities.map(&.name).should_not contain("kv")
    end
  end
end
