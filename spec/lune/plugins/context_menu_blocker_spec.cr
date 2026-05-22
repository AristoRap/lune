require "../../spec_helper"

describe Lune::Plugins::ContextMenuBlocker do
  describe "descriptor" do
    it "has correct id and label" do
      d = Lune::Plugins::ContextMenuBlocker::DESCRIPTOR
      d.id.should eq(:context_menu_blocker)
      d.label.should eq("ContextMenuBlocker")
    end

    it "has no hard deps" do
      Lune::Plugins::ContextMenuBlocker::DESCRIPTOR.deps.should be_empty
    end

    it "is not core" do
      Lune::Plugins::ContextMenuBlocker::DESCRIPTOR.core.should be_false
    end

    it "runs on every platform" do
      Lune::Plugins::ContextMenuBlocker::DESCRIPTOR.platforms.should eq([:darwin, :linux, :win32])
    end
  end

  describe "phase membership" do
    it "exposes init_js when enabled, nil otherwise" do
      blocker = Lune::Plugins::ContextMenuBlocker.new
      blocker.init_js.should be_nil
      opts = Lune::Options.new.tap { |o| o.disable_context_menu = true }
      blocker.setup(Lune::Plugin::SetupCtx.new(opts, Pointer(Void).null))
      blocker.init_js.should_not be_nil
    end

    it "does not include BindPhase" do
      Lune::Plugins::ContextMenuBlocker.new.is_a?(Lune::Bindable).should be_false
    end
  end

  describe "registry integration" do
    it "is included in the default resolved set" do
      r = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigPlugins.new(enabled: nil, disabled: nil))
      resolved.plugins.map(&.name).should contain("context_menu_blocker")
    end

    it "can be excluded via config" do
      r = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigPlugins.new(enabled: nil, disabled: ["context_menu_blocker"]))
      resolved.plugins.map(&.name).should_not contain("context_menu_blocker")
    end
  end
end
