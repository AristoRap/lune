require "../../spec_helper"

describe Lune::Plugins::FileWatch do
  describe "descriptor" do
    it "has correct id and label" do
      d = Lune::Plugins::FileWatch::DESCRIPTOR
      d.id.should eq(:file_watch)
      d.label.should eq("FileWatch")
    end

    it "declares events as a hard dep" do
      Lune::Plugins::FileWatch::DESCRIPTOR.deps.should contain(:events)
    end

    it "is not core" do
      Lune::Plugins::FileWatch::DESCRIPTOR.core.should be_false
    end
  end

  describe "name and namespace" do
    it "derives name from descriptor" do
      Lune::Plugins::FileWatch.new.name.should eq("file_watch")
    end

    it "has FileWatch binding namespace" do
      Lune::Plugins::FileWatch.new.binding_namespace.should eq("FileWatch")
    end
  end

  describe "phase membership" do
    it "includes Bindable" do
      Lune::Plugins::FileWatch.new.is_a?(Lune::Bindable).should be_true
    end

    it "includes Lifecycle" do
      Lune::Plugins::FileWatch.new.is_a?(Lune::Plugin::Lifecycle).should be_true
    end

    it "does not include WebviewInject" do
      Lune::Plugins::FileWatch.new.is_a?(Lune::Plugin::WebviewInject).should be_false
    end
  end

  describe "install" do
    it "registers watch and unwatch bindings" do
      cap = Lune::Plugins::FileWatch.new
      app = Lune::App.new
      app.install(cap)
      ids = app.bindings.map(&.id)
      ids.should contain("__lune.file_watch.watch")
      ids.should contain("__lune.file_watch.unwatch")
    end
  end

  describe "js_helpers" do
    it "exposes on, once, and off" do
      h = Lune::Plugins::FileWatch.new.js_helpers
      h.should contain("on(")
      h.should contain("once(")
      h.should contain("off(")
    end
  end

  describe "dts_helpers" do
    it "types the event payload" do
      h = Lune::Plugins::FileWatch.new.dts_helpers
      h.should contain("path")
      h.should contain("kind")
      h.should contain("modified")
      h.should contain("deleted")
    end
  end

  describe "registry integration" do
    it "cascade-disables when events is excluded" do
      r = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigPlugins.new(enabled: nil, disabled: ["events"]))
      resolved.plugins.map(&.name).should_not contain("file_watch")
    end
  end
end
