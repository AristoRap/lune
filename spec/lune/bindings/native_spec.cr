require "../../spec_helper"

private def install_all(handle, on_tray_click = nil, on_menu_click = nil)
  app = Lune::App.new
  app.install(
    Lune::Runtime::Bindings::Window.new(handle),
    Lune::Runtime::Bindings::Tray.new(on_tray_click: on_tray_click, on_menu_click: on_menu_click),
    Lune::Runtime::Bindings::Dialogs.new,
    Lune::Runtime::Bindings::Notifications.new,
    Lune::Runtime::Bindings::Screen.new
  )
  app.bindings
end

handle = Pointer(Void).null

describe "Lune::Runtime::Bindings (native)" do
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
      names.should contain("__lune.minimize")
      names.should contain("__lune.maximize")
      names.should contain("__lune.center")
      names.should contain("__lune.setTitle")
      names.should contain("__lune.setSize")
      names.should contain("__lune.openFile")
      names.should contain("__lune.saveFile")
      names.should contain("__lune.trayShow")
      names.should contain("__lune.trayHide")
      names.should contain("__lune.traySetIcon")
      names.should contain("__lune.traySetMenu")
      names.should contain("__lune.notify")
      names.should contain("__lune.screenInfo")
    end

    it "marks all bindings as internal" do
      install_all(handle).each { |b| b.internal?.should be_true }
    end
  end

  describe Lune::Runtime::Bindings::Window do
    it "minimize binding calls Window.minimize" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Window.new(handle))
      bridge.register_bindings(app.bindings)

      wv.invoke("runtime.__lune.minimize", "seq1", [] of JSON::Any)
      Lune::Native::WindowMock.calls.should contain(:minimize)
    end

    it "maximize binding calls Window.maximize" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Window.new(handle))
      bridge.register_bindings(app.bindings)

      wv.invoke("runtime.__lune.maximize", "seq2", [] of JSON::Any)
      Lune::Native::WindowMock.calls.should contain(:maximize)
    end

    it "setTitle binding forwards the title" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Window.new(handle))
      bridge.register_bindings(app.bindings)

      wv.invoke("runtime.__lune.setTitle", "seq3", [JSON::Any.new("My App")])
      Lune::Native::WindowMock.last_title.should eq("My App")
    end

    it "setSize binding forwards width and height" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Window.new(handle))
      bridge.register_bindings(app.bindings)

      wv.invoke("runtime.__lune.setSize", "seq4", [JSON::Any.new(1920_i64), JSON::Any.new(1080_i64)])
      Lune::Native::WindowMock.last_size.should eq({1920, 1080})
    end

    it "center binding calls Window.center" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Window.new(handle))
      bridge.register_bindings(app.bindings)

      wv.invoke("runtime.__lune.center", "seq5", [] of JSON::Any)
      Lune::Native::WindowMock.calls.should contain(:center)
    end
  end

  describe Lune::Runtime::Bindings::Dialogs do
    it "openFile binding returns the selected path" do
      Lune::Native::DialogMock.stub_open("/home/user/file.txt")
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Dialogs.new)
      bridge.register_bindings(app.bindings)

      wv.invoke("runtime.__lune.openFile", "seq6", [JSON::Any.new("Pick")])
      Lune::Native::DialogMock.calls.map(&.method).should contain(:open_file)
      wv.resolve_calls.find { |r| r[0] == "seq6" }.not_nil![2].should contain("/home/user/file.txt")
    end

    it "saveFile binding returns the chosen save path" do
      Lune::Native::DialogMock.stub_save("/home/user/out.csv")
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Dialogs.new)
      bridge.register_bindings(app.bindings)

      wv.invoke("runtime.__lune.saveFile", "seq7", [JSON::Any.new("Save"), JSON::Any.new("data.csv")])
      Lune::Native::DialogMock.calls.map(&.method).should contain(:save_file)
      wv.resolve_calls.find { |r| r[0] == "seq7" }.not_nil![2].should contain("/home/user/out.csv")
    end
  end

  describe Lune::Runtime::Bindings::Tray do
    it "trayShow binding calls Tray.show" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Tray.new)
      bridge.register_bindings(app.bindings)

      wv.invoke("runtime.__lune.trayShow", "seq8", [JSON::Any.new("/icon.png")])
      Lune::Native::TrayMock.calls.should contain(:show)
    end

    it "trayHide binding calls Tray.hide" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Tray.new)
      bridge.register_bindings(app.bindings)

      wv.invoke("runtime.__lune.trayHide", "seq9", [] of JSON::Any)
      Lune::Native::TrayMock.calls.should contain(:hide)
    end

    it "traySetIcon binding calls Tray.set_icon" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Tray.new)
      bridge.register_bindings(app.bindings)

      wv.invoke("runtime.__lune.traySetIcon", "seq10", [JSON::Any.new("/new.png")])
      Lune::Native::TrayMock.calls.should contain(:set_icon)
    end

    it "traySetMenu binding records items and fires callback on click" do
      clicked_id = ""
      menu_cb = ->(id : String) { clicked_id = id; nil }
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Tray.new(on_menu_click: menu_cb))
      bridge.register_bindings(app.bindings)

      json = %([{"id":"open","label":"Open"},{"id":"---","label":""},{"id":"quit","label":"Quit"}])
      wv.invoke("runtime.__lune.traySetMenu", "seq14", [JSON::Any.new(json)])
      Lune::Native::TrayMock.calls.should contain(:set_menu)
      Lune::Native::TrayMock.simulate_menu_click("open")
      clicked_id.should eq("open")
    end
  end

  describe Lune::Runtime::Bindings::Notifications do
    it "notify binding calls Notify.show" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Notifications.new)
      bridge.register_bindings(app.bindings)

      wv.invoke("runtime.__lune.notify", "seq11", [JSON::Any.new("Hello"), JSON::Any.new("World")])
      Lune::Native::NotifyMock.calls.should contain(:show)
      Lune::Native::NotifyMock.last_title.should eq("Hello")
      Lune::Native::NotifyMock.last_body.should eq("World")
    end
  end

  describe Lune::Runtime::Bindings::Screen do
    it "screenInfo binding returns width, height, and scale" do
      Lune::Native::ScreenMock.stub_info(2560, 1440, 2.0)
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Screen.new)
      bridge.register_bindings(app.bindings)

      wv.invoke("runtime.__lune.screenInfo", "seq12", [] of JSON::Any)
      resolved = wv.resolve_calls.find { |r| r[0] == "seq12" }.not_nil![2]
      resolved.should contain("2560")
      resolved.should contain("1440")
      resolved.should contain("2.0")
    end

    it "screenInfo binding calls Screen.info" do
      wv = FakeWebview.new
      bridge = Lune::Bridge.new(wv)
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Screen.new)
      bridge.register_bindings(app.bindings)

      wv.invoke("runtime.__lune.screenInfo", "seq13", [] of JSON::Any)
      Lune::Native::ScreenMock.calls.should contain(:info)
    end
  end
end
