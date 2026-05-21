require "../spec_helper"

describe Lune::Capability do
  describe Lune::Capability::Descriptor do
    it "stores id, label, deps, soft_deps, and core" do
      d = Lune::Capability::Descriptor.new(
        id: :my_cap,
        label: "MyCap",
        deps: [:events],
        soft_deps: [:stream],
        core: true,
      )
      d.id.should eq(:my_cap)
      d.label.should eq("MyCap")
      d.deps.should eq([:events])
      d.soft_deps.should eq([:stream])
      d.core.should be_true
    end

    it "defaults deps, soft_deps, and core" do
      d = Lune::Capability::Descriptor.new(id: :foo, label: "Foo")
      d.deps.should be_empty
      d.soft_deps.should be_empty
      d.core.should be_false
    end

    it "defaults platforms to all three" do
      d = Lune::Capability::Descriptor.new(id: :foo, label: "Foo")
      d.platforms.should eq([:darwin, :linux, :win32])
    end

    it "accepts a narrower platforms list" do
      d = Lune::Capability::Descriptor.new(id: :foo, label: "Foo", platforms: [:darwin])
      d.platforms.should eq([:darwin])
    end
  end

  describe "name derives from descriptor.id" do
    it "converts symbol to string" do
      Lune::Capabilities::Clipboard.new.name.should eq("clipboard")
      Lune::Capabilities::Events.new.name.should eq("events")
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

    it "Events includes WebviewInject" do
      Lune::Capabilities::Events.new.is_a?(Lune::Capability::WebviewInject).should be_true
    end

    it "Events does not include Bindable" do
      Lune::Capabilities::Events.new.is_a?(Lune::Capability::Bindable).should be_false
    end

    it "Channel includes WebviewInject" do
      Lune::Capabilities::Stream.new.is_a?(Lune::Capability::WebviewInject).should be_true
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
    it "Events is core with no deps" do
      d = Lune::Capabilities::Events::DESCRIPTOR
      d.core.should be_true
      d.deps.should be_empty
    end

    it "Channel is core with no deps" do
      d = Lune::Capabilities::Stream::DESCRIPTOR
      d.core.should be_true
      d.deps.should be_empty
    end

    it "ContextMenu declares events as a hard dep" do
      Lune::Capabilities::ContextMenu::DESCRIPTOR.deps.should contain(:events)
    end

    it "FileDrop declares events as a hard dep" do
      Lune::Capabilities::FileDrop::DESCRIPTOR.deps.should contain(:events)
    end

    it "DeepLink declares events as a hard dep" do
      Lune::Capabilities::DeepLink::DESCRIPTOR.deps.should contain(:events)
    end

    it "Tray declares events as a soft dep" do
      Lune::Capabilities::Tray::DESCRIPTOR.soft_deps.should contain(:events)
      Lune::Capabilities::Tray::DESCRIPTOR.deps.should be_empty
    end
  end

  describe "setup wires options into state" do
    it "System picks up devtools flag from options" do
      sys = Lune::Capabilities::System.new(-> { })
      sys.setup(Lune::Capability::SetupCtx.new(
        Lune::Options.new.tap { |o| o.devtools = true },
        Pointer(Void).null,
      ))

      app = Lune::App.new
      app.install(sys)

      binding = app.bindings.find { |b| b.id.ends_with?("system.environment") }
      binding.should_not be_nil
      result = binding.not_nil!.callback.call([] of JSON::Any)
      result["devtools"].as_bool.should be_true
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

private def make_registry
  Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
end

private def config_only(*names : String) : Lune::ConfigCapabilities
  Lune::ConfigCapabilities.new(only: names.to_a, exclude: nil)
end

private def config_exclude(*names : String) : Lune::ConfigCapabilities
  Lune::ConfigCapabilities.new(only: nil, exclude: names.to_a)
end

private def empty_config : Lune::ConfigCapabilities
  Lune::ConfigCapabilities.new(only: nil, exclude: nil)
end

describe Lune::Capabilities::Registry do
  describe "#resolve" do
    it "returns all capabilities when config is empty" do
      r = make_registry
      resolved = r.resolve(empty_config)
      resolved.capabilities.size.should eq(r.all.size)
      resolved.warnings.should be_empty
    end

    it "respects include list" do
      resolved = make_registry.resolve(config_only("clipboard", "filesystem"))
      resolved.capabilities.map(&.name).should contain("clipboard")
      resolved.capabilities.map(&.name).should contain("filesystem")
      resolved.capabilities.size.should eq(2)
    end

    it "respects exclude list" do
      resolved = make_registry.resolve(config_exclude("clipboard"))
      resolved.capabilities.map(&.name).should_not contain("clipboard")
    end

    it "cascade-disables a capability when its hard dep is excluded" do
      resolved = make_registry.resolve(config_exclude("events"))
      names = resolved.capabilities.map(&.name)
      names.should_not contain("context_menu")
      names.should_not contain("file_drop")
      names.should_not contain("deep_link")
    end

    it "emits a warning for each cascade-disabled capability" do
      resolved = make_registry.resolve(config_exclude("events"))
      # Use caps that are present on every platform (default platforms list)
      # so the cascade-disable step actually runs on them. FileDrop / FileWatch
      # are platform-filtered out on Win32 before the cascade step, so they
      # never produce a cascade warning there.
      resolved.warnings.any? { |w| w.includes?("ContextMenu") }.should be_true
      resolved.warnings.any? { |w| w.includes?("DeepLink") }.should be_true
    end

    it "keeps a soft-dep capability active when its soft dep is excluded" do
      resolved = make_registry.resolve(config_exclude("events"))
      resolved.capabilities.map(&.name).should contain("tray")
    end

    it "emits a soft-dep warning when soft dep is absent" do
      resolved = make_registry.resolve(config_exclude("events"))
      resolved.warnings.any? { |w| w.includes?("Tray") && w.includes?("events") }.should be_true
    end

    it "places deps before dependents in the sorted result" do
      resolved = make_registry.resolve(empty_config)
      names = resolved.capabilities.map(&.name)
      events_pos = names.index("events").not_nil!
      context_menu_pos = names.index("context_menu").not_nil!
      events_pos.should be < context_menu_pos
    end

    it "active_ids returns a set of symbols for the resolved capabilities" do
      resolved = make_registry.resolve(config_only("clipboard"))
      resolved.active_ids.should eq(Set{:clipboard})
    end
  end

  describe "platform filtering" do
    it "CURRENT_PLATFORM is one of the known OS symbols" do
      [:darwin, :linux, :win32, :unknown].should contain(Lune::Capabilities::CURRENT_PLATFORM)
    end

    it "DragOut declares darwin-only platform support" do
      Lune::Capabilities::DragOut.new.descriptor.platforms.should eq([:darwin])
    end

    it "FileWatch and FileDrop declare darwin + linux (no win32)" do
      Lune::Capabilities::FileWatch.new.descriptor.platforms.should eq([:darwin, :linux])
      Lune::Capabilities::FileDrop.new.descriptor.platforms.should eq([:darwin, :linux])
    end

    it "Tray declares darwin + linux + win32 (partial on win32 — set_menu / set_icon raise UNAVAILABLE_ON_PLATFORM)" do
      Lune::Capabilities::Tray.new.descriptor.platforms.should eq([:darwin, :linux, :win32])
    end

    it "drops platform-unsupported caps from registry.all" do
      r = make_registry
      r.all.each do |cap|
        cap.descriptor.platforms.should contain(Lune::Capabilities::CURRENT_PLATFORM)
      end
    end

    it "includes DragOut on darwin but excludes it elsewhere" do
      names = make_registry.all.map(&.name)
      if Lune::Capabilities::CURRENT_PLATFORM == :darwin
        names.should contain("drag_out")
      else
        names.should_not contain("drag_out")
      end
    end

    it "validate does not emit an unknown-capability warning for a platform-unavailable name" do
      # drag_out is a real capability — even on win32/linux where it isn't loaded,
      # the name is known and validate must not flag it as a typo.
      backend = CaptureBackend.new
      logger = Log.new("lune.spec.platform", backend, :debug)
      with_logger(logger) do
        make_registry.validate(config_only("drag_out"))
      end
      backend.entries.any? { |e| e.message.includes?("unknown capability") }.should be_false
    end

    it "validate still warns on a truly unknown capability name" do
      backend = CaptureBackend.new
      logger = Log.new("lune.spec.platform", backend, :debug)
      with_logger(logger) do
        make_registry.validate(config_only("not_a_real_cap"))
      end
      backend.entries.any? { |e| e.message.includes?("unknown capability") }.should be_true
    end
  end
end
