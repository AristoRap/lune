require "../spec_helper"

describe Lune::Capabilities::FileWatch do
  describe "descriptor" do
    it "has correct id and label" do
      d = Lune::Capabilities::FileWatch::DESCRIPTOR
      d.id.should eq(:file_watch)
      d.label.should eq("FileWatch")
    end

    it "declares events as a hard dep" do
      Lune::Capabilities::FileWatch::DESCRIPTOR.deps.should contain(:events)
    end

    it "is not core" do
      Lune::Capabilities::FileWatch::DESCRIPTOR.core.should be_false
    end
  end

  describe "name and namespace" do
    it "derives name from descriptor" do
      Lune::Capabilities::FileWatch.new.name.should eq("file_watch")
    end

    it "has FileWatch binding namespace" do
      Lune::Capabilities::FileWatch.new.binding_namespace.should eq("FileWatch")
    end
  end

  describe "phase membership" do
    it "includes Bindable" do
      Lune::Capabilities::FileWatch.new.is_a?(Lune::Bindable).should be_true
    end

    it "includes Lifecycle" do
      Lune::Capabilities::FileWatch.new.is_a?(Lune::Capability::Lifecycle).should be_true
    end

    it "does not include WebviewInject" do
      Lune::Capabilities::FileWatch.new.is_a?(Lune::Capability::WebviewInject).should be_false
    end
  end

  describe "install" do
    it "registers watch and unwatch bindings" do
      cap = Lune::Capabilities::FileWatch.new
      app = Lune::App.new
      app.install(cap)
      ids = app.bindings.map(&.id)
      ids.should contain("__lune.file_watch.watch")
      ids.should contain("__lune.file_watch.unwatch")
    end
  end

  describe "js_helpers" do
    it "exposes on, once, and off" do
      h = Lune::Capabilities::FileWatch.new.js_helpers
      h.should contain("on(")
      h.should contain("once(")
      h.should contain("off(")
    end
  end

  describe "dts_helpers" do
    it "types the event payload" do
      h = Lune::Capabilities::FileWatch.new.dts_helpers
      h.should contain("path")
      h.should contain("kind")
      h.should contain("modified")
      h.should contain("deleted")
    end
  end

  describe "registry integration" do
    it "cascade-disables when events is excluded" do
      r = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigCapabilities.new(enabled: nil, disabled: ["events"]))
      resolved.capabilities.map(&.name).should_not contain("file_watch")
    end
  end
end
