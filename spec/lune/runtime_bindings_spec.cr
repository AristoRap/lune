require "../spec_helper"

private def make_bridge
  fake = FakeWebview.new
  bridge = Lune::Bridge.new(fake)
  {fake, bridge}
end

private def install(app : Lune::App, *mods : Lune::Installable)
  app.install(*mods)
  app.bindings
end

describe "Lune::Capabilities" do
  describe Lune::Capabilities::System do
    it "does not pollute user bindings" do
      fake, bridge = make_bridge
      app = Lune::App.new
      app.install(Lune::Capabilities::System.new(on_quit: -> { }))
      bridge.register_bindings(app.bindings)
      bridge.all_bindings.values.reject(&.internal?).should be_empty
    end

    it "invokes on_quit callback when lifecycle.quit is triggered" do
      fake, bridge = make_bridge
      quit_called = false
      app = Lune::App.new
      app.install(Lune::Capabilities::System.new(on_quit: -> { quit_called = true; nil }))
      bridge.register_bindings(app.bindings)

      fake.invoke("__lune.system.quit", "seq-1", [] of JSON::Any)
      quit_called.should be_true
    end

    it "registers lifecycle.open_url and passes the url to on_open_url" do
      fake, bridge = make_bridge
      opened_url = ""
      app = Lune::App.new
      app.install(Lune::Capabilities::System.new(
        on_quit: -> { },
        on_open_url: ->(url : String) { opened_url = url; nil }
      ))
      bridge.register_bindings(app.bindings)

      fake.invoke("__lune.system.open_url", "seq-2", [JSON::Any.new("https://example.com")])

      deadline = Time.instant + 2.seconds
      while Time.instant < deadline
        break unless fake.resolve_calls.empty?
        Fiber.yield
      end

      _seq, status, _result = fake.resolve_calls[0]
      status.should eq(0)
      opened_url.should eq("https://example.com")
    end

    it "returns environment with os, arch, and debug fields" do
      fake, bridge = make_bridge
      app = Lune::App.new
      app.install(Lune::Capabilities::System.new(on_quit: -> { }, debug: true))
      bridge.register_bindings(app.bindings)

      fake.invoke("__lune.system.environment", "seq-3", [] of JSON::Any)
      _seq, status, result = fake.resolve_calls[0]
      status.should eq(0)
      env = JSON.parse(result)
      env["os"].as_s.should be_a(String)
      env["arch"].as_s.should be_a(String)
      env["debug"].as_bool.should be_true
    end

    it "reflects the debug flag in environment" do
      fake, bridge = make_bridge
      app = Lune::App.new
      app.install(Lune::Capabilities::System.new(on_quit: -> { }, debug: false))
      bridge.register_bindings(app.bindings)

      fake.invoke("__lune.system.environment", "seq-4", [] of JSON::Any)
      env = JSON.parse(fake.resolve_calls[0][2])
      env["debug"].as_bool.should be_false
    end

    it "returns a known os value" do
      fake, bridge = make_bridge
      app = Lune::App.new
      app.install(Lune::Capabilities::System.new(on_quit: -> { }))
      bridge.register_bindings(app.bindings)

      fake.invoke("__lune.system.environment", "seq-5", [] of JSON::Any)
      env = JSON.parse(fake.resolve_calls[0][2])
      ["darwin", "linux", "windows"].should contain(env["os"].as_s)
    end
  end

  describe Lune::Capabilities::Filesystem do
    it "filesystem.home_dir resolves and matches Path.home" do
      fake, bridge = make_bridge
      app = Lune::App.new
      app.install(Lune::Capabilities::Filesystem.new)
      bridge.register_bindings(app.bindings)

      fake.invoke("__lune.filesystem.home_dir", "seq-6", [] of JSON::Any)
      _, _, result = fake.resolve_calls[0]
      JSON.parse(result).as_s.should eq(Path.home.to_s)
    end

    it "filesystem.temp_dir resolves and matches Dir.tempdir" do
      fake, bridge = make_bridge
      app = Lune::App.new
      app.install(Lune::Capabilities::Filesystem.new)
      bridge.register_bindings(app.bindings)

      fake.invoke("__lune.filesystem.temp_dir", "seq-7", [] of JSON::Any)
      _, _, result = fake.resolve_calls[0]
      JSON.parse(result).as_s.should eq(Dir.tempdir)
    end

    it "filesystem.downloads_dir returns a path under the home directory" do
      fake, bridge = make_bridge
      app = Lune::App.new
      app.install(Lune::Capabilities::Filesystem.new)
      bridge.register_bindings(app.bindings)

      fake.invoke("__lune.filesystem.downloads_dir", "seq-8", [] of JSON::Any)
      _, _, result = fake.resolve_calls[0]
      JSON.parse(result).as_s.should start_with(Path.home.to_s)
    end

    it "filesystem.app_data_dir returns a non-empty string" do
      fake, bridge = make_bridge
      app = Lune::App.new
      app.install(Lune::Capabilities::Filesystem.new)
      bridge.register_bindings(app.bindings)

      fake.invoke("__lune.filesystem.app_data_dir", "seq-9", [] of JSON::Any)
      _, _, result = fake.resolve_calls[0]
      JSON.parse(result).as_s.should_not be_empty
    end
  end

  describe Lune::Capabilities::Clipboard do
    it "clipboard.read resolves with the value returned by on_read" do
      fake, bridge = make_bridge
      app = Lune::App.new
      app.install(Lune::Capabilities::Clipboard.new(
        on_read: -> : String { "clipboard content" }
      ))
      bridge.register_bindings(app.bindings)

      fake.invoke("__lune.clipboard.read", "seq-10", [] of JSON::Any)

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
      fake, bridge = make_bridge
      written = ""
      app = Lune::App.new
      app.install(Lune::Capabilities::Clipboard.new(
        on_write: ->(text : String) { written = text; nil }
      ))
      bridge.register_bindings(app.bindings)

      fake.invoke("__lune.clipboard.write", "seq-11", [JSON::Any.new("hello clipboard")])

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
      fake, bridge = make_bridge
      app = Lune::App.new
      app.install(Lune::Capabilities::Clipboard.new(
        on_read_html: -> : String { "<b>hello</b>" }
      ))
      bridge.register_bindings(app.bindings)

      fake.invoke("__lune.clipboard.read_html", "seq-20", [] of JSON::Any)

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
      fake, bridge = make_bridge
      written = ""
      app = Lune::App.new
      app.install(Lune::Capabilities::Clipboard.new(
        on_write_html: ->(html : String) { written = html; nil }
      ))
      bridge.register_bindings(app.bindings)

      fake.invoke("__lune.clipboard.write_html", "seq-21", [JSON::Any.new("<p>hi</p>")])

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
      fake, bridge = make_bridge
      app = Lune::App.new
      app.install(Lune::Capabilities::Clipboard.new(
        on_read_image: -> : String { "data:image/png;base64,abc123" }
      ))
      bridge.register_bindings(app.bindings)

      fake.invoke("__lune.clipboard.read_image", "seq-22", [] of JSON::Any)

      deadline = Time.instant + 2.seconds
      while Time.instant < deadline
        break unless fake.resolve_calls.empty?
        Fiber.yield
      end

      _, status, result = fake.resolve_calls[0]
      status.should eq(0)
      JSON.parse(result).as_s.should eq("data:image/png;base64,abc123")
    end

    it "clipboard.write_image calls on_write_image with the data URL and resolves" do
      fake, bridge = make_bridge
      written = ""
      app = Lune::App.new
      app.install(Lune::Capabilities::Clipboard.new(
        on_write_image: ->(data_url : String) { written = data_url; nil }
      ))
      bridge.register_bindings(app.bindings)

      fake.invoke("__lune.clipboard.write_image", "seq-23", [JSON::Any.new("data:image/png;base64,abc123")])

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

  describe Lune::Capabilities::ContextMenu do
    before_each { Lune::Native::MenuMock.reset }

    it "context_menu.show calls show_context_menu with the given coordinates and JSON" do
      fake, bridge = make_bridge
      app = Lune::App.new
      app.bridge = bridge

      app.install(Lune::Capabilities::ContextMenu.new)
      bridge.register_bindings(app.bindings)

      items_json = "[{\"id\":\"copy\",\"label\":\"Copy\"}]"
      fake.invoke("__lune.context_menu.show", "seq-40", [
        JSON::Any.new(15.0_f64),
        JSON::Any.new(25.0_f64),
        JSON::Any.new(items_json),
      ])

      _, status, _ = fake.resolve_calls[0]
      status.should eq(0)
      Lune::Native::MenuMock.calls.should contain(:show_context_menu)
      Lune::Native::MenuMock.last_context_json.should eq(items_json)
    end

    it "emits context_menu event to user app when an item is selected" do
      fake, bridge = make_bridge
      app = Lune::App.new
      app.bridge = bridge

      Lune::Native::MenuMock.stub_context_selection("copy")

      app.install(Lune::Capabilities::ContextMenu.new)
      bridge.register_bindings(app.bindings)

      items_json = "[{\"id\":\"copy\",\"label\":\"Copy\"}]"
      fake.invoke("__lune.context_menu.show", "seq-41", [
        JSON::Any.new(0.0_f64),
        JSON::Any.new(0.0_f64),
        JSON::Any.new(items_json),
      ])

      _, status, _ = fake.resolve_calls[0]
      status.should eq(0)
      fake.dispatch_count.should be > 0
    end
  end

  describe Lune::Capabilities::DragOut do
    before_each { Lune::Native::WindowMock.reset }

    it "drag_out.start calls start_drag_out with the given paths" do
      fake, bridge = make_bridge
      app = Lune::App.new
      app.install(Lune::Capabilities::DragOut.new)
      bridge.register_bindings(app.bindings)

      paths_json = "[\"/etc/hosts\",\"/etc/shells\"]"
      fake.invoke("__lune.drag_out.start", "seq-50", [JSON::Any.new(paths_json)])

      _, status, _ = fake.resolve_calls[0]
      status.should eq(0)
      Lune::Native::WindowMock.calls.should contain(:start_drag_out)
      Lune::Native::WindowMock.last_drag_out_paths.should eq(["/etc/hosts", "/etc/shells"])
    end
  end

  describe "Registry" do
    it "registers all capability bindings" do
      app = Lune::App.new
      Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new).all.each { |cap| app.install(cap) }

      methods = app.bindings.map(&.method)

      methods.should contain("system.quit")
      methods.should contain("system.environment")
      methods.should contain("system.open_url")
      methods.should contain("filesystem.home_dir")
      methods.should contain("clipboard.read")
      methods.should contain("clipboard.write")
      methods.should contain("clipboard.read_html")
      methods.should contain("clipboard.write_html")
      methods.should contain("clipboard.read_image")
      methods.should contain("clipboard.write_image")
      methods.should contain("context_menu.show")
      methods.should contain("drag_out.start")
      methods.should contain("window.minimize")
      methods.should contain("dialogs.open_file")
      methods.should contain("tray.show")
      methods.should contain("tray.set_menu")
      methods.should contain("notifications.notify")
      methods.should contain("screen.info")
    end

    it "marks every capability binding as internal" do
      app = Lune::App.new
      Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new).all.each { |cap| app.install(cap) }

      app.bindings.all?(&.internal?).should be_true
    end

    it "registers 45 bindings total" do
      app = Lune::App.new
      Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new).all.each { |cap| app.install(cap) }

      app.bindings.size.should eq(45)
    end
  end

  describe "Registry#active" do
    it "returns all capabilities when config has no include or exclude" do
      registry = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new)
      active = registry.active(Lune::ConfigCapabilities.new)
      active.size.should eq(registry.all.size)
    end

    it "includes a capability when its name is in the include list" do
      registry = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new)
      caps = Lune::ConfigCapabilities.new(only: ["system"])
      active = registry.active(caps)
      active.map(&.name).should contain("system")
      active.size.should eq(1)
    end

    it "does not match binding names — only capability names are valid" do
      registry = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new)
      caps = Lune::ConfigCapabilities.new(only: ["quit"])
      active = registry.active(caps)
      active.should be_empty
    end

    it "returns all capabilities when include list is empty (same as omitted)" do
      registry = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new)
      active = registry.active(Lune::ConfigCapabilities.new(only: [] of String))
      active.size.should eq(registry.all.size)
    end

    it "silently ignores nonexistent capability names in include" do
      registry = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new)
      caps = Lune::ConfigCapabilities.new(only: ["system", "nonexistent"])
      active = registry.active(caps)
      active.map(&.name).should eq(["system"])
    end

    it "excludes a capability by capability name" do
      registry = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new)
      caps = Lune::ConfigCapabilities.new(exclude: ["clipboard"])
      active = registry.active(caps)
      active.map(&.name).should_not contain("clipboard")
      active.map(&.name).should contain("system")
    end

    it "does not match binding names in exclude — only capability names" do
      registry = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new)
      caps = Lune::ConfigCapabilities.new(exclude: ["clipboardRead"])
      active = registry.active(caps)
      active.map(&.name).should contain("clipboard")
    end

    it "applies include before exclude" do
      registry = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new)
      caps = Lune::ConfigCapabilities.new(only: ["system", "clipboard"], exclude: ["clipboard"])
      active = registry.active(caps)
      active.map(&.name).should contain("system")
      active.map(&.name).should_not contain("clipboard")
    end

    it "treats include [\"*\"] as all capabilities" do
      registry = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new)
      caps = Lune::ConfigCapabilities.new(only: ["*"])
      registry.active(caps).size.should eq(registry.all.size)
    end

    it "treats include [\"all\"] as all capabilities" do
      registry = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new)
      caps = Lune::ConfigCapabilities.new(only: ["all"])
      registry.active(caps).size.should eq(registry.all.size)
    end

    it "treats exclude [\"*\"] as no capabilities" do
      registry = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new)
      caps = Lune::ConfigCapabilities.new(exclude: ["*"])
      registry.active(caps).should be_empty
    end

    it "includes core capabilities by name even when they have no bindings" do
      registry = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new)
      caps = Lune::ConfigCapabilities.new(only: ["event_bus"])
      active = registry.active(caps)
      active.map(&.name).should contain("event_bus")
    end
  end
end
