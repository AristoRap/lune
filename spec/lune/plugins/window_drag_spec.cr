require "../../spec_helper"

describe Lune::Plugins::WindowDrag do
  describe "descriptor" do
    it "has correct id and label" do
      d = Lune::Plugins::WindowDrag::DESCRIPTOR
      d.id.should eq(:window_drag)
      d.label.should eq("WindowDrag")
    end

    it "has no hard deps" do
      Lune::Plugins::WindowDrag::DESCRIPTOR.deps.should be_empty
    end

    it "is not core" do
      Lune::Plugins::WindowDrag::DESCRIPTOR.core.should be_false
    end

    it "declares darwin-only platform support" do
      Lune::Plugins::WindowDrag::DESCRIPTOR.platforms.should eq([:darwin])
    end
  end

  describe "phase membership" do
    it "includes WebviewInject" do
      Lune::Plugins::WindowDrag.new.is_a?(Lune::Plugin::WebviewInject).should be_true
    end

    it "includes Bindable (start callback is a @[Bind] method)" do
      Lune::Plugins::WindowDrag.new.is_a?(Lune::Bindable).should be_true
    end
  end

  describe "registry integration" do
    it "is in default set on darwin, filtered out elsewhere" do
      r = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      names = r.all.map(&.name)
      if Lune::Plugins::CURRENT_PLATFORM == :darwin
        names.should contain("window_drag")
      else
        names.should_not contain("window_drag")
      end
    end

    {% if flag?(:darwin) %}
      it "can be excluded via config on darwin" do
        r = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
        resolved = r.resolve(Lune::ConfigPlugins.new(enabled: nil, disabled: ["window_drag"]))
        resolved.plugins.map(&.name).should_not contain("window_drag")
      end
    {% end %}
  end
end
