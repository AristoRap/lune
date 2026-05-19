require "../../spec_helper"

describe Lune::Native::Hotkeys do
  before_each { Lune::Native::HotkeysMock.reset }

  describe ".init / simulate" do
    it "registers a handler that receives simulated accelerators" do
      received = nil
      Lune::Native::Hotkeys.init { |acc| received = acc }
      Lune::Native::HotkeysMock.simulate("Ctrl+K")
      received.should eq("Ctrl+K")
    end

    it "replaces the handler on repeated init calls" do
      first = nil
      second = nil
      Lune::Native::Hotkeys.init { |acc| first = acc }
      Lune::Native::Hotkeys.init { |acc| second = acc }
      Lune::Native::HotkeysMock.simulate("Ctrl+K")
      first.should be_nil
      second.should eq("Ctrl+K")
    end

    it "is a no-op when simulate is called before init" do
      Lune::Native::HotkeysMock.simulate("Ctrl+K")
    end
  end

  describe ".register" do
    before_each { Lune::Native::Hotkeys.init { |_| } }

    it "adds an accelerator to the registered set" do
      Lune::Native::Hotkeys.register("Ctrl+Shift+K")
      Lune::Native::HotkeysMock.registered.should contain("Ctrl+Shift+K")
    end

    it "does not duplicate an already-registered accelerator" do
      Lune::Native::Hotkeys.register("Ctrl+K")
      Lune::Native::Hotkeys.register("Ctrl+K")
      Lune::Native::HotkeysMock.registered.count { |a| a == "Ctrl+K" }.should eq(1)
    end

    it "returns true on success" do
      Lune::Native::Hotkeys.register("Ctrl+K").should be_true
    end
  end

  describe ".unregister" do
    before_each { Lune::Native::Hotkeys.init { |_| } }

    it "removes the accelerator" do
      Lune::Native::Hotkeys.register("Ctrl+K")
      Lune::Native::Hotkeys.unregister("Ctrl+K")
      Lune::Native::HotkeysMock.registered.should_not contain("Ctrl+K")
    end

    it "returns true when the accelerator was registered" do
      Lune::Native::Hotkeys.register("Ctrl+K")
      Lune::Native::Hotkeys.unregister("Ctrl+K").should be_true
    end

    it "returns false when the accelerator was not registered" do
      Lune::Native::Hotkeys.unregister("Ctrl+Z").should be_false
    end
  end

  describe ".unregister_all" do
    before_each { Lune::Native::Hotkeys.init { |_| } }

    it "clears all registered hotkeys" do
      Lune::Native::Hotkeys.register("Ctrl+A")
      Lune::Native::Hotkeys.register("Ctrl+B")
      Lune::Native::Hotkeys.unregister_all
      Lune::Native::HotkeysMock.registered.should be_empty
    end
  end
end
