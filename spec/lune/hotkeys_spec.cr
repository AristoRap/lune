require "../spec_helper"

private def make_hotkeys_bridge
  fake = FakeWebview.new
  bridge = Lune::Bridge.new(fake)
  {fake, bridge}
end

describe Lune::Capabilities::Hotkeys do
  before_each { Lune::Native::HotkeysMock.reset }

  describe "descriptor" do
    it "has correct id and label" do
      d = Lune::Capabilities::Hotkeys::DESCRIPTOR
      d.id.should eq(:hotkeys)
      d.label.should eq("Hotkeys")
    end

    it "lists events as a soft dep" do
      Lune::Capabilities::Hotkeys::DESCRIPTOR.soft_deps.should contain(:events)
    end

    it "has no hard deps" do
      Lune::Capabilities::Hotkeys::DESCRIPTOR.deps.should be_empty
    end

    it "is not core" do
      Lune::Capabilities::Hotkeys::DESCRIPTOR.core.should be_false
    end
  end

  describe "name and namespace" do
    it "derives name from descriptor" do
      Lune::Capabilities::Hotkeys.new.name.should eq("hotkeys")
    end

    it "has Hotkeys binding namespace" do
      Lune::Capabilities::Hotkeys.new.binding_namespace.should eq("Hotkeys")
    end
  end

  describe "phase membership" do
    it "includes Bindable" do
      Lune::Capabilities::Hotkeys.new.is_a?(Lune::Capability::BindPhase).should be_true
    end

    it "includes Lifecycle" do
      Lune::Capabilities::Hotkeys.new.is_a?(Lune::Capability::Lifecycle).should be_true
    end

    it "does not include WebviewInject" do
      Lune::Capabilities::Hotkeys.new.is_a?(Lune::Capability::WebviewInject).should be_false
    end
  end

  describe "install" do
    it "registers register and unregister bindings" do
      cap = Lune::Capabilities::Hotkeys.new
      app = Lune::App.new
      app.install(cap)
      ids = app.bindings.map(&.id)
      ids.should contain("__lune.hotkeys.register")
      ids.should contain("__lune.hotkeys.unregister")
    end

    it "sets up the native hotkey callback without raising" do
      cap = Lune::Capabilities::Hotkeys.new
      app = Lune::App.new
      app.install(cap)
      Lune::Native::HotkeysMock.simulate("Ctrl+K")
    end

    it "emits a hotkey event to the frontend when a hotkey fires" do
      fake, bridge = make_hotkeys_bridge
      cap = Lune::Capabilities::Hotkeys.new
      app = Lune::App.new
      app.bridge = bridge
      app.install(cap)

      before = fake.dispatch_count
      Lune::Native::HotkeysMock.simulate("Ctrl+Shift+Space")
      fake.dispatch_count.should be > before
    end

    it "does not emit when no bridge is set" do
      cap = Lune::Capabilities::Hotkeys.new
      app = Lune::App.new
      app.install(cap)
      Lune::Native::HotkeysMock.simulate("Ctrl+K")
    end
  end

  describe "js_helpers" do
    it "exposes register and unregister via bindings (not duplicated in helpers)" do
      cap = Lune::Capabilities::Hotkeys.new
      app = Lune::App.new
      app.install(cap)
      js = Lune::Generator.generate_runtime_js(app.bindings, [cap] of Lune::Capability)
      js.scan(/\bregister\(accelerator\)/).size.should eq(1)
      js.scan(/\bunregister\(accelerator\)/).size.should eq(1)
      cap.js_helpers.should_not contain("register(")
      cap.js_helpers.should_not contain("unregister(")
    end

    it "exposes on, once, and off" do
      h = Lune::Capabilities::Hotkeys.new.js_helpers
      h.should contain("on(")
      h.should contain("once(")
      h.should contain("off(")
    end
  end

  describe "dts_helpers" do
    it "declares register and unregister via bindings (not duplicated in helpers)" do
      cap = Lune::Capabilities::Hotkeys.new
      app = Lune::App.new
      app.install(cap)
      dts = Lune::Generator.generate_runtime_dts(app.bindings, [cap] of Lune::Capability)
      dts.scan(/\bregister\(accelerator: string\)/).size.should eq(1)
      dts.scan(/\bunregister\(accelerator: string\)/).size.should eq(1)
      cap.dts_helpers.should_not contain("register(")
      cap.dts_helpers.should_not contain("unregister(")
    end

    it "includes Promise<void> return types in the generated runtime" do
      cap = Lune::Capabilities::Hotkeys.new
      app = Lune::App.new
      app.install(cap)
      dts = Lune::Generator.generate_runtime_dts(app.bindings, [cap] of Lune::Capability)
      dts.should contain("Promise<void>")
    end

    it "declares on, once, and off event listeners" do
      d = Lune::Capabilities::Hotkeys.new.dts_helpers
      d.should contain("on(")
      d.should contain("once(")
      d.should contain("off(")
    end
  end

  describe "shutdown" do
    it "unregisters all hotkeys" do
      cap = Lune::Capabilities::Hotkeys.new
      app = Lune::App.new
      app.install(cap)
      Lune::Native::Hotkeys.register("Ctrl+K")
      cap.shutdown
      Lune::Native::HotkeysMock.registered.should be_empty
    end
  end
end
