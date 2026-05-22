require "../../spec_helper"

describe Lune::Plugins::Windows do
  describe "descriptor" do
    it "has correct id and label" do
      d = Lune::Plugins::Windows::DESCRIPTOR
      d.id.should eq(:windows)
      d.label.should eq("Windows")
    end

    it "has no hard deps" do
      Lune::Plugins::Windows::DESCRIPTOR.deps.should be_empty
    end

    it "is not core" do
      Lune::Plugins::Windows::DESCRIPTOR.core.should be_false
    end
  end

  describe "name and namespace" do
    it "derives name from descriptor" do
      Lune::Plugins::Windows.new.name.should eq("windows")
    end

    it "has Windows binding namespace" do
      Lune::Plugins::Windows.new.binding_namespace.should eq("Windows")
    end
  end

  describe "phase membership" do
    it "includes Bindable" do
      Lune::Plugins::Windows.new.is_a?(Lune::Bindable).should be_true
    end

    it "includes Lifecycle" do
      Lune::Plugins::Windows.new.is_a?(Lune::Plugin::Lifecycle).should be_true
    end

    it "does not include WebviewInject" do
      Lune::Plugins::Windows.new.is_a?(Lune::Plugin::WebviewInject).should be_false
    end

    it "includes MainContextAware" do
      Lune::Plugins::Windows.new.is_a?(Lune::Plugin::MainContextAware).should be_true
    end
  end

  describe "install" do
    it "registers open, close, and list bindings" do
      cap = Lune::Plugins::Windows.new
      app = Lune::App.new
      app.install(cap)
      ids = app.bindings.map(&.id)
      ids.should contain("Windows.open")
      ids.should contain("Windows.close")
      ids.should contain("Windows.list")
    end

    it "list returns empty array when no extra windows are open" do
      cap = Lune::Plugins::Windows.new
      app = Lune::App.new
      app.install(cap)
      list_b = app.bindings.find { |b| b.id == "Windows.list" }.not_nil!
      result = list_b.callback.call([] of JSON::Any)
      result.as_a.should be_empty
    end
  end

  describe "shutdown" do
    it "can be called with no windows open" do
      cap = Lune::Plugins::Windows.new
      cap.shutdown
    end
  end

  describe "registry integration" do
    it "is included in the default resolved set" do
      r = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigPlugins.new(enabled: nil, disabled: nil))
      resolved.plugins.map(&.name).should contain("windows")
    end

    it "can be excluded" do
      r = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigPlugins.new(enabled: nil, disabled: ["windows"]))
      resolved.plugins.map(&.name).should_not contain("windows")
    end
  end

  describe "runtime.d.ts signatures" do
    it "emits open(...) returning Promise<string>" do
      cap = Lune::Plugins::Windows.new
      app = Lune::App.new
      app.install(cap)
      dts = Lune::Generator.generate_runtime_dts(app.bindings, [cap] of Lune::Plugin)
      dts.should match(/open\(.+?\):\s*Promise<string>/)
    end

    it "emits list() as Promise<string[]>" do
      cap = Lune::Plugins::Windows.new
      app = Lune::App.new
      app.install(cap)
      dts = Lune::Generator.generate_runtime_dts(app.bindings, [cap] of Lune::Plugin)
      dts.should contain("list(): Promise<string[]>")
    end
  end
end
