require "../spec_helper"

describe Lune::Capabilities::ContextMenuBlocker do
  describe "descriptor" do
    it "has correct id and label" do
      d = Lune::Capabilities::ContextMenuBlocker::DESCRIPTOR
      d.id.should eq(:context_menu_blocker)
      d.label.should eq("ContextMenuBlocker")
    end

    it "has no hard deps" do
      Lune::Capabilities::ContextMenuBlocker::DESCRIPTOR.deps.should be_empty
    end

    it "is not core" do
      Lune::Capabilities::ContextMenuBlocker::DESCRIPTOR.core.should be_false
    end

    it "runs on every platform" do
      Lune::Capabilities::ContextMenuBlocker::DESCRIPTOR.platforms.should eq([:darwin, :linux, :win32])
    end
  end

  describe "phase membership" do
    it "includes WebviewInject" do
      Lune::Capabilities::ContextMenuBlocker.new.is_a?(Lune::Capability::WebviewInject).should be_true
    end

    it "does not include BindPhase" do
      Lune::Capabilities::ContextMenuBlocker.new.is_a?(Lune::Capability::BindPhase).should be_false
    end
  end

  describe "registry integration" do
    it "is included in the default resolved set" do
      r = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigCapabilities.new(enabled: nil, disabled: nil))
      resolved.capabilities.map(&.name).should contain("context_menu_blocker")
    end

    it "can be excluded via config" do
      r = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigCapabilities.new(enabled: nil, disabled: ["context_menu_blocker"]))
      resolved.capabilities.map(&.name).should_not contain("context_menu_blocker")
    end
  end
end
