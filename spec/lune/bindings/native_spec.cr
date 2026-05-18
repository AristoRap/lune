require "../../spec_helper"

private def install_all(handle, on_tray_click = nil, on_menu_click = nil)
  app = Lune::App.new
  app.install(
    Lune::Capabilities::Window.new(handle),
    Lune::Capabilities::Tray.new(on_tray_click: on_tray_click, on_menu_click: on_menu_click),
    Lune::Capabilities::Dialogs.new,
    Lune::Capabilities::Notifications.new,
    Lune::Capabilities::Screen.new
  )
  app.bindings
end

handle = Pointer(Void).null

describe "Lune::Capabilities (native)" do
  before_each do
    Lune::Native::WindowMock.reset
    Lune::Native::DialogMock.reset
    Lune::Native::TrayMock.reset
    Lune::Native::NotifyMock.reset
    Lune::Native::ScreenMock.reset
  end

  describe "all classes together" do
    it "returns Array(Lune::Binding)" do
      install_all(handle).should be_a(Array(Lune::Binding))
    end

    it "includes all expected capability names" do
      names = install_all(handle).map(&.method)
      names.should contain("window.minimize")
      names.should contain("window.maximize")
      names.should contain("window.center")
      names.should contain("window.set_title")
      names.should contain("window.set_size")
      names.should contain("dialogs.open_file")
      names.should contain("dialogs.open_dir")
      names.should contain("dialogs.open_files")
      names.should contain("dialogs.save_file")
      names.should contain("dialogs.message_info")
      names.should contain("dialogs.message_warning")
      names.should contain("dialogs.message_error")
      names.should contain("dialogs.message_question")
      names.should contain("tray.show")
      names.should contain("tray.hide")
      names.should contain("tray.set_icon")
      names.should contain("tray.set_menu")
      names.should contain("notifications.notify")
      names.should contain("screen.info")
    end

    it "marks all bindings as internal" do
      install_all(handle).each { |b| b.internal?.should be_true }
    end
  end

  describe Lune::Capabilities::Window do
    it "minimize binding calls Window.minimize" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Capabilities::Window.new(handle))
      bridge.register_bindings(app.bindings)

      wv.invoke("__lune.window.minimize", "seq1", [] of JSON::Any)
      Lune::Native::WindowMock.calls.should contain(:minimize)
    end

    it "maximize binding calls Window.maximize" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Capabilities::Window.new(handle))
      bridge.register_bindings(app.bindings)

      wv.invoke("__lune.window.maximize", "seq2", [] of JSON::Any)
      Lune::Native::WindowMock.calls.should contain(:maximize)
    end

    it "set_title binding forwards the title" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Capabilities::Window.new(handle))
      bridge.register_bindings(app.bindings)

      wv.invoke("__lune.window.set_title", "seq3", [JSON::Any.new("My App")])
      Lune::Native::WindowMock.last_title.should eq("My App")
    end

    it "set_size binding forwards width and height" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Capabilities::Window.new(handle))
      bridge.register_bindings(app.bindings)

      wv.invoke("__lune.window.set_size", "seq4", [JSON::Any.new(1920_i64), JSON::Any.new(1080_i64)])
      Lune::Native::WindowMock.last_size.should eq({1920, 1080})
    end

    it "center binding calls Window.center" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Capabilities::Window.new(handle))
      bridge.register_bindings(app.bindings)

      wv.invoke("__lune.window.center", "seq5", [] of JSON::Any)
      Lune::Native::WindowMock.calls.should contain(:center)
    end
  end

  describe Lune::Capabilities::Dialogs do
    it "open_file binding returns the selected path" do
      Lune::Native::DialogMock.stub_open("/home/user/file.txt")
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Capabilities::Dialogs.new)
      bridge.register_bindings(app.bindings)

      wv.invoke("__lune.dialogs.open_file", "seq6", [JSON::Any.new("Pick")])
      Lune::Native::DialogMock.calls.map(&.method).should contain(:open_file)
      wv.resolve_calls.find { |r| r[0] == "seq6" }.not_nil![2].should contain("/home/user/file.txt")
    end

    it "save_file binding returns the chosen save path" do
      Lune::Native::DialogMock.stub_save("/home/user/out.csv")
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Capabilities::Dialogs.new)
      bridge.register_bindings(app.bindings)

      wv.invoke("__lune.dialogs.save_file", "seq7", [JSON::Any.new("Save"), JSON::Any.new("data.csv")])
      Lune::Native::DialogMock.calls.map(&.method).should contain(:save_file)
      wv.resolve_calls.find { |r| r[0] == "seq7" }.not_nil![2].should contain("/home/user/out.csv")
    end

    it "open_dir binding returns the selected directory" do
      Lune::Native::DialogMock.stub_open_dir("/home/user/docs")
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Capabilities::Dialogs.new)
      bridge.register_bindings(app.bindings)

      wv.invoke("__lune.dialogs.open_dir", "seq8a", [JSON::Any.new("Pick folder")])
      Lune::Native::DialogMock.calls.map(&.method).should contain(:open_dir)
      wv.resolve_calls.find { |r| r[0] == "seq8a" }.not_nil![2].should contain("/home/user/docs")
    end

    it "open_files binding returns a JSON array of paths" do
      Lune::Native::DialogMock.stub_open_files(["/a/one.txt", "/b/two.txt"])
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Capabilities::Dialogs.new)
      bridge.register_bindings(app.bindings)

      wv.invoke("__lune.dialogs.open_files", "seq8b", [JSON::Any.new("Pick files")])
      Lune::Native::DialogMock.calls.map(&.method).should contain(:open_files)
      result = JSON.parse(wv.resolve_calls.find { |r| r[0] == "seq8b" }.not_nil![2])
      result.as_a.map(&.as_s).should eq(["/a/one.txt", "/b/two.txt"])
    end

    it "message_info binding resolves with nil" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Capabilities::Dialogs.new)
      bridge.register_bindings(app.bindings)

      wv.invoke("__lune.dialogs.message_info", "seq8c", [JSON::Any.new("Title"), JSON::Any.new("Hello")])
      Lune::Native::DialogMock.calls.map(&.method).should contain(:message)
      _, status, _ = wv.resolve_calls.find { |r| r[0] == "seq8c" }.not_nil!
      status.should eq(0)
    end

    it "message_question binding returns Yes or No" do
      Lune::Native::DialogMock.stub_message("Yes")
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Capabilities::Dialogs.new)
      bridge.register_bindings(app.bindings)

      wv.invoke("__lune.dialogs.message_question", "seq8d", [JSON::Any.new("Confirm"), JSON::Any.new("Are you sure?")])
      result = wv.resolve_calls.find { |r| r[0] == "seq8d" }.not_nil!
      result[1].should eq(0)
      JSON.parse(result[2]).as_s.should eq("Yes")
    end
  end

  describe Lune::Capabilities::Tray do
    it "tray.show binding calls Tray.show" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Capabilities::Tray.new)
      bridge.register_bindings(app.bindings)

      wv.invoke("__lune.tray.show", "seq8", [JSON::Any.new("/icon.png")])
      Lune::Native::TrayMock.calls.should contain(:show)
    end

    it "tray.hide binding calls Tray.hide" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Capabilities::Tray.new)
      bridge.register_bindings(app.bindings)

      wv.invoke("__lune.tray.hide", "seq9", [] of JSON::Any)
      Lune::Native::TrayMock.calls.should contain(:hide)
    end

    it "tray.set_icon binding calls Tray.set_icon" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Capabilities::Tray.new)
      bridge.register_bindings(app.bindings)

      wv.invoke("__lune.tray.set_icon", "seq10", [JSON::Any.new("/new.png")])
      Lune::Native::TrayMock.calls.should contain(:set_icon)
    end

    it "tray.set_menu binding records items and fires callback on click" do
      clicked_id = ""
      menu_cb = ->(id : String) { clicked_id = id; nil }
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Capabilities::Tray.new(on_menu_click: menu_cb))
      bridge.register_bindings(app.bindings)

      json = %([{"id":"open","label":"Open"},{"id":"---","label":""},{"id":"quit","label":"Quit"}])
      wv.invoke("__lune.tray.set_menu", "seq14", [JSON::Any.new(json)])
      Lune::Native::TrayMock.calls.should contain(:set_menu)
      Lune::Native::TrayMock.simulate_menu_click("open")
      clicked_id.should eq("open")
    end

    it "tray.set_menu default emit path does not raise without explicit callback" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Capabilities::Tray.new)
      bridge.register_bindings(app.bindings)

      json = %([{"id":"quit","label":"Quit"}])
      wv.invoke("__lune.tray.set_menu", "seq15", [JSON::Any.new(json)])
      Lune::Native::TrayMock.calls.should contain(:set_menu)
      Lune::Native::TrayMock.simulate_menu_click("quit")
    end

    it "configured? is false with all defaults" do
      Lune::Capabilities::Tray.new.configured?.should be_false
    end

    it "configured? is true with custom event name" do
      Lune::Capabilities::Tray.new(event_name: "myTray").configured?.should be_true
    end

    it "configured? is true with explicit on_menu_click override" do
      cb = ->(id : String) { nil }
      Lune::Capabilities::Tray.new(on_menu_click: cb).configured?.should be_true
    end
  end

  describe Lune::Capabilities::Notifications do
    it "notifications.notify binding calls Notify.show" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Capabilities::Notifications.new)
      bridge.register_bindings(app.bindings)

      wv.invoke("__lune.notifications.notify", "seq11", [JSON::Any.new("Hello"), JSON::Any.new("World")])
      Lune::Native::NotifyMock.calls.should contain(:show)
      Lune::Native::NotifyMock.last_title.should eq("Hello")
      Lune::Native::NotifyMock.last_body.should eq("World")
    end
  end

  describe Lune::Capabilities::Screen do
    it "screen.info binding returns width, height, and scale" do
      Lune::Native::ScreenMock.stub_info(2560, 1440, 2.0)
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Capabilities::Screen.new)
      bridge.register_bindings(app.bindings)

      wv.invoke("__lune.screen.info", "seq12", [] of JSON::Any)
      resolved = wv.resolve_calls.find { |r| r[0] == "seq12" }.not_nil![2]
      resolved.should contain("2560")
      resolved.should contain("1440")
      resolved.should contain("2.0")
    end

    it "screen.info binding calls Screen.info" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Capabilities::Screen.new)
      bridge.register_bindings(app.bindings)

      wv.invoke("__lune.screen.info", "seq13", [] of JSON::Any)
      Lune::Native::ScreenMock.calls.should contain(:info)
    end
  end
end
