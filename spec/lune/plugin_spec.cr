require "../spec_helper"

describe Lune::Plugin do
  describe Lune::Plugin::Descriptor do
    it "stores id, label, deps, soft_deps, and core" do
      d = Lune::Plugin::Descriptor.new(
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
      d = Lune::Plugin::Descriptor.new(id: :foo, label: "Foo")
      d.deps.should be_empty
      d.soft_deps.should be_empty
      d.core.should be_false
    end

    it "defaults platforms to all three" do
      d = Lune::Plugin::Descriptor.new(id: :foo, label: "Foo")
      d.platforms.should eq([:darwin, :linux, :win32])
    end

    it "accepts a narrower platforms list" do
      d = Lune::Plugin::Descriptor.new(id: :foo, label: "Foo", platforms: [:darwin])
      d.platforms.should eq([:darwin])
    end
  end

  describe "name derives from descriptor.id" do
    it "converts symbol to string" do
      Lune::Plugins::Clipboard.new.name.should eq("clipboard")
      Lune::Plugins::Events.new.name.should eq("events")
      Lune::Plugins::ContextMenu.new.name.should eq("context_menu")
      Lune::Plugins::DragOut.new.name.should eq("drag_out")
      Lune::Plugins::DeepLink.new.name.should eq("deep_link")
      Lune::Plugins::FileDrop.new.name.should eq("file_drop")
    end
  end

  describe "phase module membership" do
    it "Clipboard includes Bindable" do
      Lune::Plugins::Clipboard.new.is_a?(Lune::Bindable).should be_true
    end

    it "Filesystem includes Bindable" do
      Lune::Plugins::Filesystem.new.is_a?(Lune::Bindable).should be_true
    end

    it "Events includes WebviewInject" do
      Lune::Plugins::Events.new.is_a?(Lune::Plugin::WebviewInject).should be_true
    end

    it "Events does not include Bindable" do
      Lune::Plugins::Events.new.is_a?(Lune::Bindable).should be_false
    end

    it "Channel includes WebviewInject" do
      Lune::Plugins::Stream.new.is_a?(Lune::Plugin::WebviewInject).should be_true
    end

    it "FileDrop includes WebviewInject" do
      Lune::Plugins::FileDrop.new.is_a?(Lune::Plugin::WebviewInject).should be_true
    end

    it "FileDrop does not include Bindable" do
      Lune::Plugins::FileDrop.new.is_a?(Lune::Bindable).should be_false
    end

    it "ContextMenu includes Bindable and exposes init_js" do
      cap = Lune::Plugins::ContextMenu.new
      cap.is_a?(Lune::Bindable).should be_true
      cap.init_js.should_not be_nil
    end
  end

  describe "descriptor fields per plugin" do
    it "Events is core with no deps" do
      d = Lune::Plugins::Events::DESCRIPTOR
      d.core.should be_true
      d.deps.should be_empty
    end

    it "Channel is core with no deps" do
      d = Lune::Plugins::Stream::DESCRIPTOR
      d.core.should be_true
      d.deps.should be_empty
    end

    it "ContextMenu declares events as a hard dep" do
      Lune::Plugins::ContextMenu::DESCRIPTOR.deps.should contain(:events)
    end

    it "FileDrop declares events as a hard dep" do
      Lune::Plugins::FileDrop::DESCRIPTOR.deps.should contain(:events)
    end

    it "DeepLink declares events as a hard dep" do
      Lune::Plugins::DeepLink::DESCRIPTOR.deps.should contain(:events)
    end

    it "Tray declares events as a soft dep" do
      Lune::Plugins::Tray::DESCRIPTOR.soft_deps.should contain(:events)
      Lune::Plugins::Tray::DESCRIPTOR.deps.should be_empty
    end
  end

  describe "setup wires options into state" do
    it "System picks up devtools flag from options" do
      sys = Lune::Plugins::System.new(-> { })
      sys.setup(Lune::Plugin::SetupCtx.new(
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
      cap = Lune::Plugins::Window.new
      sentinel = Pointer(Void).new(0xdeadbeef_u64)
      cap.setup(Lune::Plugin::SetupCtx.new(Lune::Options.new, sentinel))
      cap.@handle.should eq(sentinel)
    end

    it "Tray picks up event_name from options" do
      cap = Lune::Plugins::Tray.new
      opts = Lune::Options.new
      opts.tray { |t| t.event = "myTrayEvent" }
      cap.setup(Lune::Plugin::SetupCtx.new(opts, Pointer(Void).null))
      cap.@event_name.should eq("myTrayEvent")
    end
  end
end

private def make_registry
  Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
end

private def config_enabled(*names : String) : Lune::ConfigPlugins
  Lune::ConfigPlugins.new(enabled: names.to_a, disabled: nil)
end

private def config_disabled(*names : String) : Lune::ConfigPlugins
  Lune::ConfigPlugins.new(enabled: nil, disabled: names.to_a)
end

private def empty_config : Lune::ConfigPlugins
  Lune::ConfigPlugins.new(enabled: nil, disabled: nil)
end

describe Lune::Plugins::Registry do
  describe "#resolve" do
    it "returns all plugins when config is empty" do
      r = make_registry
      resolved = r.resolve(empty_config)
      resolved.plugins.size.should eq(r.all.size)
      resolved.warnings.should be_empty
    end

    it "respects include list" do
      resolved = make_registry.resolve(config_enabled("clipboard", "filesystem"))
      resolved.plugins.map(&.name).should contain("clipboard")
      resolved.plugins.map(&.name).should contain("filesystem")
      resolved.plugins.size.should eq(2)
    end

    it "respects exclude list" do
      resolved = make_registry.resolve(config_disabled("clipboard"))
      resolved.plugins.map(&.name).should_not contain("clipboard")
    end

    it "cascade-disables a plugin when its hard dep is excluded" do
      resolved = make_registry.resolve(config_disabled("events"))
      names = resolved.plugins.map(&.name)
      names.should_not contain("context_menu")
      names.should_not contain("file_drop")
      names.should_not contain("deep_link")
    end

    it "emits a warning for each cascade-disabled plugin" do
      resolved = make_registry.resolve(config_disabled("events"))
      # Use caps that are present on every platform (default platforms list)
      # so the cascade-disable step actually runs on them. FileDrop / FileWatch
      # are platform-filtered out on Win32 before the cascade step, so they
      # never produce a cascade warning there.
      resolved.warnings.any? { |w| w.includes?("ContextMenu") }.should be_true
      resolved.warnings.any? { |w| w.includes?("DeepLink") }.should be_true
    end

    it "keeps a soft-dep plugin active when its soft dep is excluded" do
      resolved = make_registry.resolve(config_disabled("events"))
      resolved.plugins.map(&.name).should contain("tray")
    end

    it "emits a soft-dep warning when soft dep is absent" do
      resolved = make_registry.resolve(config_disabled("events"))
      resolved.warnings.any? { |w| w.includes?("Tray") && w.includes?("events") }.should be_true
    end

    it "places deps before dependents in the sorted result" do
      resolved = make_registry.resolve(empty_config)
      names = resolved.plugins.map(&.name)
      events_pos = names.index("events").not_nil!
      context_menu_pos = names.index("context_menu").not_nil!
      events_pos.should be < context_menu_pos
    end

    it "active_ids returns a set of symbols for the resolved plugins" do
      resolved = make_registry.resolve(config_enabled("clipboard"))
      resolved.active_ids.should eq(Set{:clipboard})
    end
  end

  describe "#validate_resolve_install" do
    it "returns the same ResolvedSet that resolve() would" do
      app = Lune::App.new
      resolved = make_registry.validate_resolve_install(config_enabled("clipboard"), app)
      resolved.active_ids.should eq(Set{:clipboard})
    end

    it "installs BindPhase plugins into the target app" do
      app = Lune::App.new
      make_registry.validate_resolve_install(config_enabled("clipboard"), app)
      app.bindings.map(&.id).any?(&.includes?("clipboard")).should be_true
    end

    it "skips plugins that are not BindPhase" do
      # Events is WebviewInject only — must not be installed via BindCtx.
      app = Lune::App.new
      make_registry.validate_resolve_install(config_enabled("events"), app)
      app.bindings.map(&.id).any?(&.includes?("events")).should be_false
    end

    it "logs resolve warnings via Lune.logger" do
      backend = CaptureBackend.new
      logger = Log.new("lune.spec.vri", backend, :debug)
      with_logger(logger) do
        make_registry.validate_resolve_install(config_disabled("events"), Lune::App.new)
      end
      backend.entries.any? { |e| e.message.includes?("ContextMenu") }.should be_true
    end

    it "logs validate warnings for unknown plugin names" do
      backend = CaptureBackend.new
      logger = Log.new("lune.spec.vri", backend, :debug)
      with_logger(logger) do
        make_registry.validate_resolve_install(config_enabled("not_a_real_cap"), Lune::App.new)
      end
      backend.entries.any? { |e| e.message.includes?("unknown plugin") }.should be_true
    end
  end

  describe "platform filtering" do
    it "CURRENT_PLATFORM is one of the known OS symbols" do
      [:darwin, :linux, :win32, :unknown].should contain(Lune::Plugins::CURRENT_PLATFORM)
    end

    it "DragOut declares darwin-only platform support" do
      Lune::Plugins::DragOut.new.descriptor.platforms.should eq([:darwin])
    end

    it "FileWatch and FileDrop declare darwin + linux (no win32)" do
      Lune::Plugins::FileWatch.new.descriptor.platforms.should eq([:darwin, :linux])
      Lune::Plugins::FileDrop.new.descriptor.platforms.should eq([:darwin, :linux])
    end

    it "Tray declares darwin + linux + win32 (partial on win32 — set_menu / set_icon raise UNAVAILABLE_ON_PLATFORM)" do
      Lune::Plugins::Tray.new.descriptor.platforms.should eq([:darwin, :linux, :win32])
    end

    it "drops platform-unsupported caps from registry.all" do
      r = make_registry
      r.all.each do |cap|
        cap.descriptor.platforms.should contain(Lune::Plugins::CURRENT_PLATFORM)
      end
    end

    it "includes DragOut on darwin but excludes it elsewhere" do
      names = make_registry.all.map(&.name)
      if Lune::Plugins::CURRENT_PLATFORM == :darwin
        names.should contain("drag_out")
      else
        names.should_not contain("drag_out")
      end
    end

    it "validate does not emit an unknown-plugin warning for a platform-unavailable name" do
      # drag_out is a real plugin — even on win32/linux where it isn't loaded,
      # the name is known and validate must not flag it as a typo.
      backend = CaptureBackend.new
      logger = Log.new("lune.spec.platform", backend, :debug)
      with_logger(logger) do
        make_registry.validate(config_enabled("drag_out"))
      end
      backend.entries.any? { |e| e.message.includes?("unknown plugin") }.should be_false
    end

    it "validate still warns on a truly unknown plugin name" do
      backend = CaptureBackend.new
      logger = Log.new("lune.spec.platform", backend, :debug)
      with_logger(logger) do
        make_registry.validate(config_enabled("not_a_real_cap"))
      end
      backend.entries.any? { |e| e.message.includes?("unknown plugin") }.should be_true
    end
  end
end
