require "../../spec_helper"

describe Lune::Plugins::EditShortcuts do
  describe "descriptor" do
    it "has correct id and label" do
      d = Lune::Plugins::EditShortcuts::DESCRIPTOR
      d.id.should eq(:edit_shortcuts)
      d.label.should eq("EditShortcuts")
    end

    it "has no hard deps" do
      Lune::Plugins::EditShortcuts::DESCRIPTOR.deps.should be_empty
    end

    it "is not core (users can opt out via lune.yml)" do
      Lune::Plugins::EditShortcuts::DESCRIPTOR.core.should be_false
    end

    it "runs on every platform" do
      Lune::Plugins::EditShortcuts::DESCRIPTOR.platforms.should eq([:darwin, :linux, :win32])
    end
  end

  describe "phase membership" do
    it "exposes a boot-time init_js script" do
      Lune::Plugins::EditShortcuts.new.init_js.should_not be_nil
    end

    it "does not include BindPhase (no JS namespace exposed)" do
      Lune::Plugins::EditShortcuts.new.is_a?(Lune::Bindable).should be_false
    end
  end

  describe "registry integration" do
    it "is included in the default resolved set" do
      r = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::Config::Plugins.new(enabled: nil, disabled: nil))
      resolved.plugins.map(&.name).should contain("edit_shortcuts")
    end

    it "can be excluded via config" do
      r = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::Config::Plugins.new(enabled: nil, disabled: ["edit_shortcuts"]))
      resolved.plugins.map(&.name).should_not contain("edit_shortcuts")
    end
  end
end
