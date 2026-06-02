require "../../spec_helper"

private def install_all(handle, on_tray_click = nil, on_menu_click = nil)
  app = Lune::App.new
  window_plugin = Lune::Plugins::Window.new
  window_plugin.setup(Lune::Plugin::SetupCtx.new(Lune::Options.new, handle))
  app.install(window_plugin)

  tray_plugin = Lune::Plugins::Tray.new
  tray_opts = Lune::Options.new
  tray_opts.tray.on_click = on_tray_click if on_tray_click
  tray_opts.tray.on_menu_click = on_menu_click if on_menu_click
  tray_plugin.setup(Lune::Plugin::SetupCtx.new(tray_opts, handle))
  app.install(tray_plugin)

  app.install(Lune::Plugins::Dialogs.new)
  app.install(Lune::Plugins::System.new)
  app.bindings
end

handle = Pointer(Void).null

describe "Lune::Plugins (native)" do
  before_each do
    Lune::Native::WindowMock.reset
    Lune::Native::DialogsMock.reset
    Lune::Native::TrayMock.reset
    Lune::Native::NotificationsMock.reset
    Lune::Native::ScreenMock.reset
  end

  describe "all classes together" do
    it "returns Array(Lune::Binding)" do
      install_all(handle).should be_a(Array(Lune::Binding))
    end

    it "includes all expected plugin bindings (by id)" do
      ids = install_all(handle).map(&.id)
      ids.should contain("Lune.Plugins.Window.minimize")
      ids.should contain("Lune.Plugins.Window.maximize")
      ids.should contain("Lune.Plugins.Window.center")
      ids.should contain("Lune.Plugins.Window.setTitle")
      ids.should contain("Lune.Plugins.Window.setSize")
      ids.should contain("Lune.Plugins.Dialogs.openFile")
      ids.should contain("Lune.Plugins.Dialogs.openDir")
      ids.should contain("Lune.Plugins.Dialogs.openFiles")
      ids.should contain("Lune.Plugins.Dialogs.saveFile")
      ids.should contain("Lune.Plugins.Dialogs.messageInfo")
      ids.should contain("Lune.Plugins.Dialogs.messageWarning")
      ids.should contain("Lune.Plugins.Dialogs.messageError")
      ids.should contain("Lune.Plugins.Dialogs.messageQuestion")
      ids.should contain("Lune.Plugins.Tray.show")
      ids.should contain("Lune.Plugins.Tray.hide")
      ids.should contain("Lune.Plugins.Tray.setIcon")
      ids.should contain("Lune.Plugins.Tray.setMenu")
      ids.should contain("Lune.Plugins.System.notify")
      ids.should contain("Lune.Plugins.System.screenInfo")
    end

    it "marks all bindings as internal" do
      install_all(handle).each { |b| b.internal?.should be_true }
    end
  end

  describe Lune::Plugins::Window do
    it "minimize binding calls Window.minimize" do
      wv = FakeWebview.new
      app = Lune::App.new
      window_cap = Lune::Plugins::Window.new
      window_cap.setup(Lune::Plugin::SetupCtx.new(Lune::Options.new, handle))
      app.install(window_cap)
      bridge = Lune::Bridge.new(wv, app.registry)
      bridge.register_bindings(app.bindings)

      wv.invoke("Lune.Plugins.Window.minimize", "seq1", [] of JSON::Any)
      Lune::Native::WindowMock.calls.should contain(:minimize)
    end

    it "maximize binding calls Window.maximize" do
      wv = FakeWebview.new
      app = Lune::App.new
      window_cap = Lune::Plugins::Window.new
      window_cap.setup(Lune::Plugin::SetupCtx.new(Lune::Options.new, handle))
      app.install(window_cap)
      bridge = Lune::Bridge.new(wv, app.registry)
      bridge.register_bindings(app.bindings)

      wv.invoke("Lune.Plugins.Window.maximize", "seq2", [] of JSON::Any)
      Lune::Native::WindowMock.calls.should contain(:maximize)
    end

    it "set_title binding forwards the title" do
      wv = FakeWebview.new
      app = Lune::App.new
      window_cap = Lune::Plugins::Window.new
      window_cap.setup(Lune::Plugin::SetupCtx.new(Lune::Options.new, handle))
      app.install(window_cap)
      bridge = Lune::Bridge.new(wv, app.registry)
      bridge.register_bindings(app.bindings)

      wv.invoke("Lune.Plugins.Window.setTitle", "seq3", [JSON.parse(%({"title": "My App"}))])
      Lune::Native::WindowMock.last_title.should eq("My App")
    end

    it "set_size binding forwards width and height" do
      wv = FakeWebview.new
      app = Lune::App.new
      window_cap = Lune::Plugins::Window.new
      window_cap.setup(Lune::Plugin::SetupCtx.new(Lune::Options.new, handle))
      app.install(window_cap)
      bridge = Lune::Bridge.new(wv, app.registry)
      bridge.register_bindings(app.bindings)

      wv.invoke("Lune.Plugins.Window.setSize", "seq4", [JSON.parse(%({"width": 1920, "height": 1080}))])
      Lune::Native::WindowMock.last_size.should eq({1920, 1080})
    end

    it "center binding calls Window.center" do
      wv = FakeWebview.new
      app = Lune::App.new
      window_cap = Lune::Plugins::Window.new
      window_cap.setup(Lune::Plugin::SetupCtx.new(Lune::Options.new, handle))
      app.install(window_cap)
      bridge = Lune::Bridge.new(wv, app.registry)
      bridge.register_bindings(app.bindings)

      wv.invoke("Lune.Plugins.Window.center", "seq5", [] of JSON::Any)
      Lune::Native::WindowMock.calls.should contain(:center)
    end
  end

  describe Lune::Plugins::Dialogs do
    it "open_file binding returns the selected path" do
      Lune::Native::DialogsMock.stub_open("/home/user/file.txt")
      wv = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::Dialogs.new)
      bridge = Lune::Bridge.new(wv, app.registry)
      bridge.register_bindings(app.bindings)

      wv.invoke("Lune.Plugins.Dialogs.openFile", "seq6", [JSON.parse(%({"prompt": "Pick", "filters": []}))])
      Lune::Native::DialogsMock.calls.map(&.method).should contain(:open_file)
      wv.resolve_calls.find { |r| r[0] == "seq6" }.not_nil![2].should contain("/home/user/file.txt")
    end

    it "save_file binding returns the chosen save path" do
      Lune::Native::DialogsMock.stub_save("/home/user/out.csv")
      wv = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::Dialogs.new)
      bridge = Lune::Bridge.new(wv, app.registry)
      bridge.register_bindings(app.bindings)

      wv.invoke("Lune.Plugins.Dialogs.saveFile", "seq7", [JSON.parse(%({"prompt": "Save", "filename": "data.csv", "filters": []}))])
      Lune::Native::DialogsMock.calls.map(&.method).should contain(:save_file)
      wv.resolve_calls.find { |r| r[0] == "seq7" }.not_nil![2].should contain("/home/user/out.csv")
    end

    it "open_dir binding returns the selected directory" do
      Lune::Native::DialogsMock.stub_open_dir("/home/user/docs")
      wv = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::Dialogs.new)
      bridge = Lune::Bridge.new(wv, app.registry)
      bridge.register_bindings(app.bindings)

      wv.invoke("Lune.Plugins.Dialogs.openDir", "seq8a", [JSON.parse(%({"prompt": "Pick folder"}))])
      Lune::Native::DialogsMock.calls.map(&.method).should contain(:open_dir)
      wv.resolve_calls.find { |r| r[0] == "seq8a" }.not_nil![2].should contain("/home/user/docs")
    end

    it "open_files binding returns a JSON array of paths" do
      Lune::Native::DialogsMock.stub_open_files(["/a/one.txt", "/b/two.txt"])
      wv = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::Dialogs.new)
      bridge = Lune::Bridge.new(wv, app.registry)
      bridge.register_bindings(app.bindings)

      wv.invoke("Lune.Plugins.Dialogs.openFiles", "seq8b", [JSON.parse(%({"prompt": "Pick files", "filters": []}))])
      Lune::Native::DialogsMock.calls.map(&.method).should contain(:open_files)
      result = JSON.parse(wv.resolve_calls.find { |r| r[0] == "seq8b" }.not_nil![2])
      result.as_a.map(&.as_s).should eq(["/a/one.txt", "/b/two.txt"])
    end

    it "message_info binding resolves with nil" do
      wv = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::Dialogs.new)
      bridge = Lune::Bridge.new(wv, app.registry)
      bridge.register_bindings(app.bindings)

      wv.invoke("Lune.Plugins.Dialogs.messageInfo", "seq8c", [JSON.parse(%({"title": "Title", "message": "Hello"}))])
      Lune::Native::DialogsMock.calls.map(&.method).should contain(:message)
      _, status, _ = wv.resolve_calls.find { |r| r[0] == "seq8c" }.not_nil!
      status.should eq(0)
    end

    it "message_question binding returns Yes or No" do
      Lune::Native::DialogsMock.stub_message("Yes")
      wv = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::Dialogs.new)
      bridge = Lune::Bridge.new(wv, app.registry)
      bridge.register_bindings(app.bindings)

      wv.invoke("Lune.Plugins.Dialogs.messageQuestion", "seq8d", [JSON.parse(%({"title": "Confirm", "message": "Are you sure?"}))])
      result = wv.resolve_calls.find { |r| r[0] == "seq8d" }.not_nil!
      result[1].should eq(0)
      JSON.parse(result[2]).as_s.should eq("Yes")
    end
  end

  describe Lune::Plugins::Tray do
    it "tray.show binding calls Tray.show" do
      wv = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::Tray.new)
      bridge = Lune::Bridge.new(wv, app.registry)
      bridge.register_bindings(app.bindings)

      wv.invoke("Lune.Plugins.Tray.show", "seq8", [JSON.parse(%({"iconPath": "/icon.png"}))])
      Lune::Native::TrayMock.calls.should contain(:show)
    end

    it "tray.hide binding calls Tray.hide" do
      wv = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::Tray.new)
      bridge = Lune::Bridge.new(wv, app.registry)
      bridge.register_bindings(app.bindings)

      wv.invoke("Lune.Plugins.Tray.hide", "seq9", [] of JSON::Any)
      Lune::Native::TrayMock.calls.should contain(:hide)
    end

    it "tray.set_icon binding calls Tray.set_icon" do
      wv = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::Tray.new)
      bridge = Lune::Bridge.new(wv, app.registry)
      bridge.register_bindings(app.bindings)

      wv.invoke("Lune.Plugins.Tray.setIcon", "seq10", [JSON.parse(%({"path": "/new.png"}))])
      Lune::Native::TrayMock.calls.should contain(:set_icon)
    end

    it "tray.set_menu binding records items and fires callback on click" do
      clicked_id = ""
      menu_cb = ->(id : String) { clicked_id = id; nil }
      wv = FakeWebview.new
      app = Lune::App.new
      plugin = Lune::Plugins::Tray.new
      plugin.config.on_menu_click = menu_cb
      plugin.setup(Lune::Plugin::SetupCtx.new(Lune::Options.new, Pointer(Void).null))
      app.install(plugin)
      bridge = Lune::Bridge.new(wv, app.registry)
      bridge.register_bindings(app.bindings)

      json = %([{"id":"open","label":"Open"},{"id":"---","label":""},{"id":"quit","label":"Quit"}])
      wv.invoke("Lune.Plugins.Tray.setMenu", "seq14", [JSON.parse(%({"items": #{json}}))])
      Lune::Native::TrayMock.calls.should contain(:set_menu)
      Lune::Native::TrayMock.simulate_menu_click("open")
      clicked_id.should eq("open")
    end

    it "tray.set_menu default emit path does not raise without explicit callback" do
      wv = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::Tray.new)
      bridge = Lune::Bridge.new(wv, app.registry)
      bridge.register_bindings(app.bindings)

      json = %([{"id":"quit","label":"Quit"}])
      wv.invoke("Lune.Plugins.Tray.setMenu", "seq15", [JSON.parse(%({"items": #{json}}))])
      Lune::Native::TrayMock.calls.should contain(:set_menu)
      Lune::Native::TrayMock.simulate_menu_click("quit")
    end

    it "configured? is false with all defaults" do
      Lune::Plugins::Tray.new.configured?.should be_false
    end

    it "configured? is true with custom event name" do
      plugin = Lune::Plugins::Tray.new
      plugin.config.event = "myTray"
      plugin.configured?.should be_true
    end

    it "configured? is true with explicit on_menu_click override" do
      plugin = Lune::Plugins::Tray.new
      plugin.config.on_menu_click = ->(id : String) { nil }
      plugin.configured?.should be_true
    end
  end

  describe Lune::Plugins::System do
    it "System.notify binding calls Native::Notifications.show" do
      wv = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::System.new)
      bridge = Lune::Bridge.new(wv, app.registry)
      bridge.register_bindings(app.bindings)

      wv.invoke("Lune.Plugins.System.notify", "seq11", [JSON.parse(%({"title": "Hello", "body": "World"}))])

      # System.notify is async (its native impl shells out on Win32),
      # so the callback runs on @async_pool. Wait for the resolve to land.
      deadline = Time.instant + 2.seconds
      while Time.instant < deadline
        break unless wv.resolve_calls.empty?
        Fiber.yield
      end

      Lune::Native::NotificationsMock.calls.should contain(:show)
      Lune::Native::NotificationsMock.last_title.should eq("Hello")
      Lune::Native::NotificationsMock.last_body.should eq("World")
    end

    it "System.screen_info binding returns width, height, and scale" do
      Lune::Native::ScreenMock.stub_info(2560, 1440, 2.0)
      wv = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::System.new)
      bridge = Lune::Bridge.new(wv, app.registry)
      bridge.register_bindings(app.bindings)

      wv.invoke("Lune.Plugins.System.screenInfo", "seq12", [] of JSON::Any)
      resolved = wv.resolve_calls.find { |r| r[0] == "seq12" }.not_nil![2]
      resolved.should contain("2560")
      resolved.should contain("1440")
      resolved.should contain("2.0")
    end

    it "System.screen_info binding calls Native::Screen.info" do
      wv = FakeWebview.new
      app = Lune::App.new
      app.install(Lune::Plugins::System.new)
      bridge = Lune::Bridge.new(wv, app.registry)
      bridge.register_bindings(app.bindings)

      wv.invoke("Lune.Plugins.System.screenInfo", "seq13", [] of JSON::Any)
      Lune::Native::ScreenMock.calls.should contain(:info)
    end
  end
end
