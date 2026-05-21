require "../spec_helper"

describe Lune::Capabilities::Windows do
  describe "descriptor" do
    it "has correct id and label" do
      d = Lune::Capabilities::Windows::DESCRIPTOR
      d.id.should eq(:windows)
      d.label.should eq("Windows")
    end

    it "has no hard deps" do
      Lune::Capabilities::Windows::DESCRIPTOR.deps.should be_empty
    end

    it "is not core" do
      Lune::Capabilities::Windows::DESCRIPTOR.core.should be_false
    end
  end

  describe "name and namespace" do
    it "derives name from descriptor" do
      Lune::Capabilities::Windows.new.name.should eq("windows")
    end

    it "has Windows binding namespace" do
      Lune::Capabilities::Windows.new.binding_namespace.should eq("Windows")
    end
  end

  describe "phase membership" do
    it "includes Bindable" do
      Lune::Capabilities::Windows.new.is_a?(Lune::Capability::Bindable).should be_true
    end

    it "includes Lifecycle" do
      Lune::Capabilities::Windows.new.is_a?(Lune::Capability::Lifecycle).should be_true
    end

    it "does not include WebviewInject" do
      Lune::Capabilities::Windows.new.is_a?(Lune::Capability::WebviewInject).should be_false
    end
  end

  describe "install" do
    it "registers open, close, and list bindings" do
      cap = Lune::Capabilities::Windows.new
      app = Lune::App.new
      app.install(cap)
      ids = app.bindings.map(&.id)
      ids.should contain("__lune.windows.open")
      ids.should contain("__lune.windows.close")
      ids.should contain("__lune.windows.list")
    end

    it "list returns empty array when no extra windows are open" do
      cap = Lune::Capabilities::Windows.new
      app = Lune::App.new
      app.install(cap)
      list_b = app.bindings.find { |b| b.id == "__lune.windows.list" }.not_nil!
      result = list_b.callback.call([] of JSON::Any)
      result.as_a.should be_empty
    end
  end

  describe "shutdown" do
    it "can be called with no windows open" do
      cap = Lune::Capabilities::Windows.new
      cap.shutdown
    end
  end

  describe "registry integration" do
    it "is included in the default resolved set" do
      r = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigCapabilities.new(enabled: nil, disabled: nil))
      resolved.capabilities.map(&.name).should contain("windows")
    end

    it "can be excluded" do
      r = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigCapabilities.new(enabled: nil, disabled: ["windows"]))
      resolved.capabilities.map(&.name).should_not contain("windows")
    end
  end
end
