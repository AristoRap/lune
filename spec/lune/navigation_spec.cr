require "../spec_helper"

describe Lune::Capabilities::Navigation do
  describe "descriptor" do
    it "has correct id and label" do
      d = Lune::Capabilities::Navigation::DESCRIPTOR
      d.id.should eq(:navigation)
      d.label.should eq("Navigation")
    end

    it "has no hard deps" do
      Lune::Capabilities::Navigation::DESCRIPTOR.deps.should be_empty
    end

    it "is not core" do
      Lune::Capabilities::Navigation::DESCRIPTOR.core.should be_false
    end

    it "runs on every platform" do
      Lune::Capabilities::Navigation::DESCRIPTOR.platforms.should eq([:darwin, :linux, :win32])
    end
  end

  describe "phase membership" do
    it "includes WebviewInject" do
      Lune::Capabilities::Navigation.new.is_a?(Lune::Capability::WebviewInject).should be_true
    end

    it "does not include BindPhase (no JS namespace exposed)" do
      Lune::Capabilities::Navigation.new.is_a?(Lune::Capability::BindPhase).should be_false
    end
  end

  describe "registry integration" do
    it "is included in the default resolved set" do
      r = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigCapabilities.new(enabled: nil, disabled: nil))
      resolved.capabilities.map(&.name).should contain("navigation")
    end

    it "can be excluded via config" do
      r = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigCapabilities.new(enabled: nil, disabled: ["navigation"]))
      resolved.capabilities.map(&.name).should_not contain("navigation")
    end
  end
end
