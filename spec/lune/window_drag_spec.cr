require "../spec_helper"

describe Lune::Capabilities::WindowDrag do
  describe "descriptor" do
    it "has correct id and label" do
      d = Lune::Capabilities::WindowDrag::DESCRIPTOR
      d.id.should eq(:window_drag)
      d.label.should eq("WindowDrag")
    end

    it "has no hard deps" do
      Lune::Capabilities::WindowDrag::DESCRIPTOR.deps.should be_empty
    end

    it "is not core" do
      Lune::Capabilities::WindowDrag::DESCRIPTOR.core.should be_false
    end

    it "declares darwin-only platform support" do
      Lune::Capabilities::WindowDrag::DESCRIPTOR.platforms.should eq([:darwin])
    end
  end

  describe "phase membership" do
    it "includes WebviewInject" do
      Lune::Capabilities::WindowDrag.new.is_a?(Lune::Capability::WebviewInject).should be_true
    end

    it "does not include BindPhase" do
      Lune::Capabilities::WindowDrag.new.is_a?(Lune::Capability::BindPhase).should be_false
    end
  end

  describe "registry integration" do
    it "is in default set on darwin, filtered out elsewhere" do
      r = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      names = r.all.map(&.name)
      if Lune::Capabilities::CURRENT_PLATFORM == :darwin
        names.should contain("window_drag")
      else
        names.should_not contain("window_drag")
      end
    end

    {% if flag?(:darwin) %}
      it "can be excluded via config on darwin" do
        r = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
        resolved = r.resolve(Lune::ConfigCapabilities.new(enabled: nil, disabled: ["window_drag"]))
        resolved.capabilities.map(&.name).should_not contain("window_drag")
      end
    {% end %}
  end
end
