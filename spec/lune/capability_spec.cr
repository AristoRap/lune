require "../spec_helper"

describe Lune::Capability do
  describe Lune::Capability::Descriptor do
    it "stores id, label, deps, soft_deps, and core" do
      d = Lune::Capability::Descriptor.new(
        id: :my_cap,
        label: "MyCap",
        deps: [:event_bus],
        soft_deps: [:channel],
        core: true,
      )
      d.id.should eq(:my_cap)
      d.label.should eq("MyCap")
      d.deps.should eq([:event_bus])
      d.soft_deps.should eq([:channel])
      d.core.should be_true
    end

    it "defaults deps, soft_deps, and core" do
      d = Lune::Capability::Descriptor.new(id: :foo, label: "Foo")
      d.deps.should be_empty
      d.soft_deps.should be_empty
      d.core.should be_false
    end
  end

  describe "name derives from descriptor.id" do
    it "converts symbol to string" do
      Lune::Capabilities::Clipboard.new.name.should eq("clipboard")
      Lune::Capabilities::EventBus.new.name.should eq("event_bus")
      Lune::Capabilities::ContextMenu.new.name.should eq("context_menu")
      Lune::Capabilities::DragOut.new.name.should eq("drag_out")
      Lune::Capabilities::DeepLink.new.name.should eq("deep_link")
      Lune::Capabilities::FileDrop.new.name.should eq("file_drop")
    end
  end

  describe "phase module membership" do
    it "Clipboard includes Bindable" do
      Lune::Capabilities::Clipboard.new.is_a?(Lune::Capability::Bindable).should be_true
    end

    it "Filesystem includes Bindable" do
      Lune::Capabilities::Filesystem.new.is_a?(Lune::Capability::Bindable).should be_true
    end

    it "EventBus includes WebviewInject" do
      Lune::Capabilities::EventBus.new.is_a?(Lune::Capability::WebviewInject).should be_true
    end

    it "EventBus does not include Bindable" do
      Lune::Capabilities::EventBus.new.is_a?(Lune::Capability::Bindable).should be_false
    end

    it "Channel includes WebviewInject" do
      Lune::Capabilities::Channel.new.is_a?(Lune::Capability::WebviewInject).should be_true
    end

    it "FileDrop includes WebviewInject" do
      Lune::Capabilities::FileDrop.new.is_a?(Lune::Capability::WebviewInject).should be_true
    end

    it "FileDrop does not include Bindable" do
      Lune::Capabilities::FileDrop.new.is_a?(Lune::Capability::Bindable).should be_false
    end

    it "ContextMenu includes both Bindable and WebviewInject" do
      cap = Lune::Capabilities::ContextMenu.new
      cap.is_a?(Lune::Capability::Bindable).should be_true
      cap.is_a?(Lune::Capability::WebviewInject).should be_true
    end
  end

  describe "descriptor fields per capability" do
    it "EventBus is core with no deps" do
      d = Lune::Capabilities::EventBus::DESCRIPTOR
      d.core.should be_true
      d.deps.should be_empty
    end

    it "Channel is core with no deps" do
      d = Lune::Capabilities::Channel::DESCRIPTOR
      d.core.should be_true
      d.deps.should be_empty
    end

    it "ContextMenu declares event_bus as a hard dep" do
      Lune::Capabilities::ContextMenu::DESCRIPTOR.deps.should contain(:event_bus)
    end

    it "FileDrop declares event_bus as a hard dep" do
      Lune::Capabilities::FileDrop::DESCRIPTOR.deps.should contain(:event_bus)
    end

    it "DeepLink declares event_bus as a hard dep" do
      Lune::Capabilities::DeepLink::DESCRIPTOR.deps.should contain(:event_bus)
    end

    it "Tray declares event_bus as a soft dep" do
      Lune::Capabilities::Tray::DESCRIPTOR.soft_deps.should contain(:event_bus)
      Lune::Capabilities::Tray::DESCRIPTOR.deps.should be_empty
    end
  end

  describe "setup wires options into state" do
    it "System picks up debug flag from options" do
      sys = Lune::Capabilities::System.new(-> { })
      sys.setup(Lune::Capability::SetupCtx.new(
        Lune::Options.new.tap { |o| o.debug = true },
        Pointer(Void).null,
      ))

      app = Lune::App.new
      sys.install(app)

      binding = app.bindings.find { |b| b.id.ends_with?("system.environment") }
      binding.should_not be_nil
      result = binding.not_nil!.callback.call([] of JSON::Any)
      result["debug"].as_bool.should be_true
    end

    it "Window picks up handle from setup" do
      cap = Lune::Capabilities::Window.new
      sentinel = Pointer(Void).new(0xdeadbeef_u64)
      cap.setup(Lune::Capability::SetupCtx.new(Lune::Options.new, sentinel))
      cap.@handle.should eq(sentinel)
    end

    it "Tray picks up event_name from options" do
      cap = Lune::Capabilities::Tray.new
      opts = Lune::Options.new
      opts.tray { |t| t.event = "myTrayEvent" }
      cap.setup(Lune::Capability::SetupCtx.new(opts, Pointer(Void).null))
      cap.@event_name.should eq("myTrayEvent")
    end
  end
end
