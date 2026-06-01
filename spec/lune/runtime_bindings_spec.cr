require "../spec_helper"

# Build a Bridge wired to the app's registry (the Bindable macro populated it
# during install). The Bridge dispatches by binding id through this registry.
private def bridge_for(app : Lune::App, fake : FakeWebview) : Lune::Bridge
  bridge = Lune::Bridge.new(fake, app.registry)
  bridge.register_bindings(app.bindings)
  bridge
end

private def install(app : Lune::App, *mods : Lune::Installable)
  app.install(*mods)
  app.bindings
end

describe "Lune::Plugins" do
  describe Lune::Plugins::System do
    it "does not pollute user bindings" do
      fake = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::System.new(on_quit: -> { }))
      bridge = bridge_for(app, fake)
      bridge.all_bindings.values.reject(&.internal?).should be_empty
    end

    it "invokes on_quit callback when lifecycle.quit is triggered" do
      fake = FakeWebview.new
      quit_called = false
      app = Lune::App.new
      app.install(Lune::Plugins::System.new(on_quit: -> { quit_called = true; nil }))
      bridge_for(app, fake)

      fake.invoke("Lune.Plugins.System.quit", "seq-1", [] of JSON::Any)
      quit_called.should be_true
    end

    it "registers lifecycle.open_url and passes the url to on_open_url" do
      fake = FakeWebview.new
      opened_url = ""
      app = Lune::App.new
      app.install(Lune::Plugins::System.new(
        on_quit: -> { },
        on_open_url: ->(url : String) { opened_url = url; nil }
      ))
      bridge_for(app, fake)

      fake.invoke("Lune.Plugins.System.openUrl", "seq-2", [JSON.parse(%({"url": "https://example.com"}))])

      deadline = Time.instant + 2.seconds
      while Time.instant < deadline
        break unless fake.resolve_calls.empty?
        Fiber.yield
      end

      _seq, status, _result = fake.resolve_calls[0]
      status.should eq(0)
      opened_url.should eq("https://example.com")
    end

    it "returns environment with os, arch, and devtools fields" do
      fake = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::System.new(on_quit: -> { }, devtools: true))
      bridge_for(app, fake)

      fake.invoke("Lune.Plugins.System.environment", "seq-3", [] of JSON::Any)
      _seq, status, result = fake.resolve_calls[0]
      status.should eq(0)
      env = JSON.parse(result)
      env["os"].as_s.should be_a(String)
      env["arch"].as_s.should be_a(String)
      env["devtools"].as_bool.should be_true
    end

    it "reflects the devtools flag in environment" do
      fake = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::System.new(on_quit: -> { }, devtools: false))
      bridge_for(app, fake)

      fake.invoke("Lune.Plugins.System.environment", "seq-4", [] of JSON::Any)
      env = JSON.parse(fake.resolve_calls[0][2])
      env["devtools"].as_bool.should be_false
    end

    it "returns a known os value" do
      fake = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::System.new(on_quit: -> { }))
      bridge_for(app, fake)

      fake.invoke("Lune.Plugins.System.environment", "seq-5", [] of JSON::Any)
      env = JSON.parse(fake.resolve_calls[0][2])
      # os is an OS enum; Crystal's default Enum#to_json lowercases, and vow
      # derives the union from that same serialization — so wire and type agree.
      ["darwin", "linux", "windows"].should contain(env["os"].as_s)
    end
  end

  describe Lune::Plugins::Filesystem do
    it "filesystem.home_dir resolves and matches Path.home" do
      fake = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::Filesystem.new)
      bridge_for(app, fake)

      fake.invoke("Lune.Plugins.Filesystem.homeDir", "seq-6", [] of JSON::Any)
      _, _, result = fake.resolve_calls[0]
      JSON.parse(result).as_s.should eq(Path.home.to_s)
    end

    it "filesystem.temp_dir resolves and matches Dir.tempdir" do
      fake = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::Filesystem.new)
      bridge_for(app, fake)

      fake.invoke("Lune.Plugins.Filesystem.tempDir", "seq-7", [] of JSON::Any)
      _, _, result = fake.resolve_calls[0]
      JSON.parse(result).as_s.should eq(Dir.tempdir)
    end

    it "filesystem.downloads_dir returns a path under the home directory" do
      fake = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::Filesystem.new)
      bridge_for(app, fake)

      fake.invoke("Lune.Plugins.Filesystem.downloadsDir", "seq-8", [] of JSON::Any)
      _, _, result = fake.resolve_calls[0]
      JSON.parse(result).as_s.should start_with(Path.home.to_s)
    end

    it "filesystem.app_data_dir returns a non-empty string" do
      fake = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::Filesystem.new)
      bridge_for(app, fake)

      fake.invoke("Lune.Plugins.Filesystem.appDataDir", "seq-9", [] of JSON::Any)
      _, _, result = fake.resolve_calls[0]
      JSON.parse(result).as_s.should_not be_empty
    end
  end

  describe Lune::Plugins::Clipboard do
    it "clipboard.read resolves with the value returned by on_read" do
      fake = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::Clipboard.new(
        on_read: -> : String { "clipboard content" }
      ))
      bridge_for(app, fake)

      fake.invoke("Lune.Plugins.Clipboard.read", "seq-10", [] of JSON::Any)

      deadline = Time.instant + 2.seconds
      while Time.instant < deadline
        break unless fake.resolve_calls.empty?
        Fiber.yield
      end

      _, status, result = fake.resolve_calls[0]
      status.should eq(0)
      JSON.parse(result).as_s.should eq("clipboard content")
    end

    it "clipboard.write calls on_write with the provided text and resolves" do
      fake = FakeWebview.new
      written = ""
      app = Lune::App.new
      app.install(Lune::Plugins::Clipboard.new(
        on_write: ->(text : String) { written = text; nil }
      ))
      bridge_for(app, fake)

      fake.invoke("Lune.Plugins.Clipboard.write", "seq-11", [JSON.parse(%({"text": "hello clipboard"}))])

      deadline = Time.instant + 2.seconds
      while Time.instant < deadline
        break unless fake.resolve_calls.empty?
        Fiber.yield
      end

      _, status, _ = fake.resolve_calls[0]
      status.should eq(0)
      written.should eq("hello clipboard")
    end

    it "clipboard.read_html resolves with HTML from on_read_html" do
      fake = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::Clipboard.new(
        on_read_html: -> : String { "<b>hello</b>" }
      ))
      bridge_for(app, fake)

      fake.invoke("Lune.Plugins.Clipboard.readHtml", "seq-20", [] of JSON::Any)

      deadline = Time.instant + 2.seconds
      while Time.instant < deadline
        break unless fake.resolve_calls.empty?
        Fiber.yield
      end

      _, status, result = fake.resolve_calls[0]
      status.should eq(0)
      JSON.parse(result).as_s.should eq("<b>hello</b>")
    end

    it "clipboard.write_html calls on_write_html with the HTML and resolves" do
      fake = FakeWebview.new
      written = ""
      app = Lune::App.new
      app.install(Lune::Plugins::Clipboard.new(
        on_write_html: ->(html : String) { written = html; nil }
      ))
      bridge_for(app, fake)

      fake.invoke("Lune.Plugins.Clipboard.writeHtml", "seq-21", [JSON.parse(%({"html": "<p>hi</p>"}))])

      deadline = Time.instant + 2.seconds
      while Time.instant < deadline
        break unless fake.resolve_calls.empty?
        Fiber.yield
      end

      _, status, _ = fake.resolve_calls[0]
      status.should eq(0)
      written.should eq("<p>hi</p>")
    end

    it "clipboard.read_image resolves with a data URL from on_read_image" do
      fake = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::Clipboard.new(
        on_read_image: -> : String { "data:image/png;base64,abc123" }
      ))
      bridge_for(app, fake)

      fake.invoke("Lune.Plugins.Clipboard.readImage", "seq-22", [] of JSON::Any)

      deadline = Time.instant + 2.seconds
      while Time.instant < deadline
        break unless fake.resolve_calls.empty?
        Fiber.yield
      end

      _, status, result = fake.resolve_calls[0]
      status.should eq(0)
      JSON.parse(result).as_s.should eq("data:image/png;base64,abc123")
    end

    it "clipboard.read_image surfaces a Lune::Error from on_read_image with its code" do
      # Mirrors the Win32 default: callback raises Lune::Error with code
      # "UNAVAILABLE_ON_PLATFORM", bridge forwards it as a typed JS LuneError
      # (status 1, body has {code: ..., error: ...}). Catchable with .catch in
      # user code the same way platform-gated plugin rejections are.
      fake = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::Clipboard.new(
        on_read_image: -> : String {
          raise Lune::Error.new("UNAVAILABLE_ON_PLATFORM", "Lune.Plugins.Clipboard.readImage is not available on win32")
        }
      ))
      bridge_for(app, fake)

      fake.invoke("Lune.Plugins.Clipboard.readImage", "seq-img-err", [] of JSON::Any)

      deadline = Time.instant + 2.seconds
      while Time.instant < deadline
        break unless fake.resolve_calls.empty?
        Fiber.yield
      end

      _, status, result = fake.resolve_calls[0]
      status.should eq(1)
      payload = JSON.parse(result)
      payload["code"].as_s.should eq("UNAVAILABLE_ON_PLATFORM")
      payload["error"].as_s.should contain("Lune.Plugins.Clipboard.readImage")
    end

    it "clipboard.write_image calls on_write_image with the data URL and resolves" do
      fake = FakeWebview.new
      written = ""
      app = Lune::App.new
      app.install(Lune::Plugins::Clipboard.new(
        on_write_image: ->(data_url : String) { written = data_url; nil }
      ))
      bridge_for(app, fake)

      fake.invoke("Lune.Plugins.Clipboard.writeImage", "seq-23", [JSON.parse(%({"dataUrl": "data:image/png;base64,abc123"}))])

      deadline = Time.instant + 2.seconds
      while Time.instant < deadline
        break unless fake.resolve_calls.empty?
        Fiber.yield
      end

      _, status, _ = fake.resolve_calls[0]
      status.should eq(0)
      written.should eq("data:image/png;base64,abc123")
    end
  end

  describe Lune::Plugins::ContextMenu do
    before_each { Lune::Native::MenuMock.reset }

    it "context_menu.show calls show_context_menu with the given coordinates and JSON" do
      fake = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::ContextMenu.new)
      app.bridge = bridge_for(app, fake)

      items_json = "[{\"id\":\"copy\",\"label\":\"Copy\"}]"
      fake.invoke("Lune.Plugins.ContextMenu.show", "seq-40", [
        JSON.parse(%({"x": 15.0, "y": 25.0, "itemsJson": #{items_json.to_json}})),
      ])

      _, status, _ = fake.resolve_calls[0]
      status.should eq(0)
      Lune::Native::MenuMock.calls.should contain(:show_context_menu)
      Lune::Native::MenuMock.last_context_json.should eq(items_json)
    end

    it "emits context_menu event to user app when an item is selected" do
      fake = FakeWebview.new
      app = Lune::App.new

      Lune::Native::MenuMock.stub_context_selection("copy")

      app.install(Lune::Plugins::ContextMenu.new)
      app.bridge = bridge_for(app, fake)

      items_json = "[{\"id\":\"copy\",\"label\":\"Copy\"}]"
      fake.invoke("Lune.Plugins.ContextMenu.show", "seq-41", [
        JSON.parse(%({"x": 0.0, "y": 0.0, "itemsJson": #{items_json.to_json}})),
      ])

      _, status, _ = fake.resolve_calls[0]
      status.should eq(0)
      fake.dispatch_count.should be > 0
    end
  end

  describe Lune::Plugins::Tray do
    before_each do
      Lune::Native::TrayMock.reset
      Lune::Native::Tray.set_menu([] of {id: String, label: String})
    end

    it "tray.show registers a non-nil left-click callback" do
      fake = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::Tray.new)
      bridge_for(app, fake)

      fake.invoke("Lune.Plugins.Tray.show", "seq-tray-1", [JSON.parse(%({"iconPath": ""}))])

      Lune::Native::TrayMock.calls.should contain(:show)
      Lune::Native::TrayMock.last_click_cb.should_not be_nil
    end

    it "default left-click emits trayEvent with left_click payload" do
      fake = FakeWebview.new
      app = Lune::App.new
      app.event.mark_ready
      app.install(Lune::Plugins::Tray.new)
      app.bridge = bridge_for(app, fake)

      fake.invoke("Lune.Plugins.Tray.show", "seq-tray-2", [JSON.parse(%({"iconPath": ""}))])
      Lune::Native::TrayMock.simulate_click

      fake.eval_calls.any?(&.includes?("left_click")).should be_true
    end

    it "tray.popup_menu invokes the native popup" do
      fake = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::Tray.new)
      bridge_for(app, fake)

      fake.invoke("Lune.Plugins.Tray.popupMenu", "seq-tray-3", [] of JSON::Any)

      deadline = Time.instant + 2.seconds
      while Time.instant < deadline
        break unless fake.resolve_calls.empty?
        Fiber.yield
      end

      _, status, _ = fake.resolve_calls[0]
      status.should eq(0)
      Lune::Native::TrayMock.calls.should contain(:popup_menu)
    end

    it "user-provided on_click override skips default emission" do
      fake = FakeWebview.new
      app = Lune::App.new
      clicked = 0

      plugin = Lune::Plugins::Tray.new
      plugin.config.on_click = -> { clicked += 1; nil }
      plugin.setup(Lune::Plugin::SetupCtx.new(Lune::Options.new, Pointer(Void).null))
      app.install(plugin)
      app.bridge = bridge_for(app, fake)

      fake.invoke("Lune.Plugins.Tray.show", "seq-tray-5", [JSON.parse(%({"iconPath": ""}))])
      Lune::Native::TrayMock.simulate_click

      clicked.should eq(1)
      fake.eval_calls.any?(&.includes?("trayEvent")).should be_false
    end

    it "auto_show triggers native show on install when set" do
      app = Lune::App.new

      plugin = Lune::Plugins::Tray.new
      plugin.config.auto_show = true
      plugin.setup(Lune::Plugin::SetupCtx.new(Lune::Options.new, Pointer(Void).null))
      app.install(plugin)

      Lune::Native::TrayMock.calls.should contain(:show)
    end

    it "auto_show is false by default — no native show happens on install" do
      app = Lune::App.new

      plugin = Lune::Plugins::Tray.new
      plugin.setup(Lune::Plugin::SetupCtx.new(Lune::Options.new, Pointer(Void).null))
      app.install(plugin)

      Lune::Native::TrayMock.calls.should_not contain(:show)
    end
  end

  describe Lune::Plugins::DragOut do
    before_each { Lune::Native::WindowMock.reset }

    it "drag_out.start calls start_drag_out with the given paths" do
      fake = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::DragOut.new)
      bridge_for(app, fake)

      fake.invoke("Lune.Plugins.DragOut.start", "seq-50", [JSON.parse(%({"paths": ["/etc/hosts", "/etc/shells"]}))])

      _, status, _ = fake.resolve_calls[0]
      status.should eq(0)
      Lune::Native::WindowMock.calls.should contain(:start_drag_out)
      Lune::Native::WindowMock.last_drag_out_paths.should eq(["/etc/hosts", "/etc/shells"])
    end
  end

  describe "Registry" do
    it "registers all cross-platform plugin bindings" do
      app = Lune::App.new
      Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new).all.each { |plugin| app.install(plugin) }

      ids = app.bindings.map(&.id)

      # These bindings exist on every platform — regressions here mean a
      # cross-platform plugin's `install` quietly dropped a binding.
      ids.should contain("Lune.Plugins.System.quit")
      ids.should contain("Lune.Plugins.System.environment")
      ids.should contain("Lune.Plugins.System.openUrl")
      ids.should contain("Lune.Plugins.Filesystem.homeDir")
      ids.should contain("Lune.Plugins.Clipboard.read")
      ids.should contain("Lune.Plugins.Clipboard.write")
      ids.should contain("Lune.Plugins.Clipboard.readHtml")
      ids.should contain("Lune.Plugins.Clipboard.writeHtml")
      ids.should contain("Lune.Plugins.Clipboard.readImage")
      ids.should contain("Lune.Plugins.Clipboard.writeImage")
      ids.should contain("Lune.Plugins.ContextMenu.show")
      ids.should contain("Lune.Plugins.Window.minimize")
      ids.should contain("Lune.Plugins.Dialogs.openFile")
      ids.should contain("Lune.Plugins.System.notify")
      ids.should contain("Lune.Plugins.System.screenInfo")
      ids.should contain("Lune.Plugins.Event.emit")
      ids.should contain("Lune.Plugins.Navigation.changed")
    end

    it "registers platform-gated bindings only on supported platforms" do
      app = Lune::App.new
      Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new).all.each { |plugin| app.install(plugin) }
      ids = app.bindings.map(&.id)

      case Lune::Plugins::CURRENT_PLATFORM
      when :darwin
        ids.should contain("Lune.Plugins.DragOut.start")
        ids.should contain("Lune.Plugins.Window.startDrag")
        ids.should contain("Lune.Plugins.Tray.show")
        ids.should contain("Lune.Plugins.Tray.setMenu")
        ids.should contain("Lune.Plugins.Tray.popupMenu")
        ids.should contain("Lune.Plugins.FileWatch.watch")
      when :linux
        ids.should_not contain("Lune.Plugins.DragOut.start")
        ids.should_not contain("Lune.Plugins.Window.startDrag")
        ids.should contain("Lune.Plugins.Tray.show")
        ids.should contain("Lune.Plugins.FileWatch.watch")
      when :win32
        ids.should_not contain("Lune.Plugins.DragOut.start")
        # Window.start_drag ships on Win32 via ReleaseCapture + WM_NCLBUTTONDOWN/HTCAPTION.
        ids.should contain("Lune.Plugins.Window.startDrag")
        # Tray ships fully on Win32 — show/hide/clicks via Shell_NotifyIconW,
        # menus via CreatePopupMenu + TrackPopupMenu, icons via LoadImageW.
        ids.should contain("Lune.Plugins.Tray.show")
        ids.should contain("Lune.Plugins.Tray.hide")
        ids.should contain("Lune.Plugins.Tray.setMenu")
        # FileWatch ships on Win32 via ReadDirectoryChangesW + IOCP.
        ids.should contain("Lune.Plugins.FileWatch.watch")
      end
    end

    it "marks every plugin binding as internal" do
      app = Lune::App.new
      Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new).all.each { |plugin| app.install(plugin) }

      app.bindings.all?(&.internal?).should be_true
    end

    it "registers the correct number of bindings for the current platform" do
      app = Lune::App.new
      Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new).all.each { |plugin| app.install(plugin) }

      # Per-platform totals — bump these when you add/remove a binding on any
      # plugin. Decreases when a plugin is platform-gated out.
      # Baseline includes Event.emit, Navigation.changed, Introspection.manifest
      # (all cross-platform) and Window.start_drag (darwin + win32; Linux still
      # needs _NET_WM_MOVERESIZE so the binding stays compiled out via
      # {% if flag?(:darwin) || flag?(:win32) %} on the Window plugin).
      #   darwin = 64 baseline (Event.emit + Navigation.changed + Introspection.manifest + Window.start_drag)
      #   linux  = 64 - DragOut(1) - Window.start_drag(1)  = 62
      #   win32  = 64 - DragOut(1)                         = 63
      expected = case Lune::Plugins::CURRENT_PLATFORM
                 when :darwin then 64
                 when :linux  then 62
                 when :win32  then 63
                 else              64
                 end

      app.bindings.size.should eq(expected)
    end
  end

  describe "Registry#active" do
    it "returns all plugins when config has no include or exclude" do
      registry = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new)
      active = registry.active(Lune::Config::Plugins.new)
      active.size.should eq(registry.all.size)
    end

    it "includes a plugin when its name is in the include list" do
      registry = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new)
      plugins = Lune::Config::Plugins.new(enabled: ["system"])
      active = registry.active(plugins)
      active.map(&.name).should contain("system")
      active.size.should eq(1)
    end

    it "does not match binding names — only plugin names are valid" do
      registry = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new)
      plugins = Lune::Config::Plugins.new(enabled: ["quit"])
      active = registry.active(plugins)
      active.should be_empty
    end

    it "returns all plugins when include list is empty (same as omitted)" do
      registry = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new)
      active = registry.active(Lune::Config::Plugins.new(enabled: [] of String))
      active.size.should eq(registry.all.size)
    end

    it "silently ignores nonexistent plugin names in include" do
      registry = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new)
      plugins = Lune::Config::Plugins.new(enabled: ["system", "nonexistent"])
      active = registry.active(plugins)
      active.map(&.name).should eq(["system"])
    end

    it "excludes a plugin by plugin name" do
      registry = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new)
      plugins = Lune::Config::Plugins.new(disabled: ["clipboard"])
      active = registry.active(plugins)
      active.map(&.name).should_not contain("clipboard")
      active.map(&.name).should contain("system")
    end

    it "does not match binding names in exclude — only plugin names" do
      registry = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new)
      plugins = Lune::Config::Plugins.new(disabled: ["clipboardRead"])
      active = registry.active(plugins)
      active.map(&.name).should contain("clipboard")
    end

    it "applies include before exclude" do
      registry = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new)
      plugins = Lune::Config::Plugins.new(enabled: ["system", "clipboard"], disabled: ["clipboard"])
      active = registry.active(plugins)
      active.map(&.name).should contain("system")
      active.map(&.name).should_not contain("clipboard")
    end

    it "treats include [\"*\"] as all plugins" do
      registry = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new)
      plugins = Lune::Config::Plugins.new(enabled: ["*"])
      registry.active(plugins).size.should eq(registry.all.size)
    end

    it "treats include [\"all\"] as all plugins" do
      registry = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new)
      plugins = Lune::Config::Plugins.new(enabled: ["all"])
      registry.active(plugins).size.should eq(registry.all.size)
    end

    it "treats exclude [\"*\"] as no plugins" do
      registry = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new)
      plugins = Lune::Config::Plugins.new(disabled: ["*"])
      registry.active(plugins).should be_empty
    end

    it "includes core plugins by name even when they have no bindings" do
      registry = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new)
      plugins = Lune::Config::Plugins.new(enabled: ["event"])
      active = registry.active(plugins)
      active.map(&.name).should contain("event")
    end
  end
end
