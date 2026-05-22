require "../../spec_helper"

private def make_hotkeys_bridge
  fake = FakeWebview.new
  bridge = Lune::Bridge.new(fake)
  {fake, bridge}
end

describe Lune::Plugins::Hotkeys do
  before_each { Lune::Native::HotkeysMock.reset }

  describe "descriptor" do
    it "has correct id and label" do
      d = Lune::Plugins::Hotkeys::DESCRIPTOR
      d.id.should eq(:hotkeys)
      d.label.should eq("Hotkeys")
    end

    it "lists events as a soft dep" do
      Lune::Plugins::Hotkeys::DESCRIPTOR.soft_deps.should contain(:events)
    end

    it "has no hard deps" do
      Lune::Plugins::Hotkeys::DESCRIPTOR.deps.should be_empty
    end

    it "is not core" do
      Lune::Plugins::Hotkeys::DESCRIPTOR.core.should be_false
    end
  end

  describe "name and namespace" do
    it "derives name from descriptor" do
      Lune::Plugins::Hotkeys.new.name.should eq("hotkeys")
    end

    it "has Hotkeys binding namespace" do
      Lune::Plugins::Hotkeys.new.binding_namespace.should eq("Lune::Plugins::Hotkeys")
    end
  end

  describe "phase membership" do
    it "includes Bindable" do
      Lune::Plugins::Hotkeys.new.is_a?(Lune::Bindable).should be_true
    end

    it "includes Lifecycle" do
      Lune::Plugins::Hotkeys.new.is_a?(Lune::Plugin::Lifecycle).should be_true
    end

    it "does not include WebviewInject" do
      Lune::Plugins::Hotkeys.new.is_a?(Lune::Plugin::WebviewInject).should be_false
    end
  end

  describe "install" do
    it "registers register and unregister bindings" do
      plugin = Lune::Plugins::Hotkeys.new
      app = Lune::App.new
      app.install(plugin)
      ids = app.bindings.map(&.id)
      ids.should contain("Lune.Plugins.Hotkeys.register")
      ids.should contain("Lune.Plugins.Hotkeys.unregister")
    end

    it "sets up the native hotkey callback without raising" do
      plugin = Lune::Plugins::Hotkeys.new
      app = Lune::App.new
      app.install(plugin)
      Lune::Native::HotkeysMock.simulate("Ctrl+K")
    end

    it "emits a hotkey event to the frontend when a hotkey fires" do
      fake, bridge = make_hotkeys_bridge
      plugin = Lune::Plugins::Hotkeys.new
      app = Lune::App.new
      app.bridge = bridge
      app.install(plugin)

      before = fake.dispatch_count
      Lune::Native::HotkeysMock.simulate("Ctrl+Shift+Space")
      fake.dispatch_count.should be > before
    end

    it "does not emit when no bridge is set" do
      plugin = Lune::Plugins::Hotkeys.new
      app = Lune::App.new
      app.install(plugin)
      Lune::Native::HotkeysMock.simulate("Ctrl+K")
    end
  end

  describe "js_helpers" do
    it "exposes register and unregister via bindings (not duplicated in helpers)" do
      plugin = Lune::Plugins::Hotkeys.new
      app = Lune::App.new
      app.install(plugin)
      js = Lune::Generator.generate_runtime_js(app.bindings, [plugin] of Lune::Plugin)
      js.scan(/\bregister\(accelerator\)/).size.should eq(1)
      js.scan(/\bunregister\(accelerator\)/).size.should eq(1)
      plugin.js_helpers.should_not contain("register(")
      plugin.js_helpers.should_not contain("unregister(")
    end

    it "exposes on, once, and off" do
      h = Lune::Plugins::Hotkeys.new.js_helpers
      h.should contain("on(")
      h.should contain("once(")
      h.should contain("off(")
    end
  end

  describe "dts_helpers" do
    it "declares register and unregister via bindings (not duplicated in helpers)" do
      plugin = Lune::Plugins::Hotkeys.new
      app = Lune::App.new
      app.install(plugin)
      dts = Lune::Generator.generate_runtime_dts(app.bindings, [plugin] of Lune::Plugin)
      dts.scan(/\bregister\(accelerator: string\)/).size.should eq(1)
      dts.scan(/\bunregister\(accelerator: string\)/).size.should eq(1)
      plugin.dts_helpers.should_not contain("register(")
      plugin.dts_helpers.should_not contain("unregister(")
    end

    it "includes Promise<void> return types in the generated runtime" do
      plugin = Lune::Plugins::Hotkeys.new
      app = Lune::App.new
      app.install(plugin)
      dts = Lune::Generator.generate_runtime_dts(app.bindings, [plugin] of Lune::Plugin)
      dts.should contain("Promise<void>")
    end

    it "declares on, once, and off event listeners" do
      d = Lune::Plugins::Hotkeys.new.dts_helpers
      d.should contain("on(")
      d.should contain("once(")
      d.should contain("off(")
    end
  end

  describe "shutdown" do
    it "unregisters all hotkeys" do
      plugin = Lune::Plugins::Hotkeys.new
      app = Lune::App.new
      app.install(plugin)
      Lune::Native::Hotkeys.register("Ctrl+K")
      plugin.shutdown
      Lune::Native::HotkeysMock.registered.should be_empty
    end
  end
end
