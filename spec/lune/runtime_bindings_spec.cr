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

describe "Lune::Runtime::Bindings" do
  describe Lune::Runtime::Bindings::Lifecycle do
    it "does not pollute user bindings" do
      fake, bridge = make_bridge
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Lifecycle.new(on_quit: -> { }))
      bridge.register_bindings(app.bindings)
      bridge.all_bindings.values.reject(&.internal?).should be_empty
    end

    it "invokes on_quit when __lune.quit is called" do
      fake, bridge = make_bridge
      quit_called = false
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Lifecycle.new(on_quit: -> { quit_called = true; nil }))
      bridge.register_bindings(app.bindings)

      fake.invoke("runtime.__lune.quit", "seq-1", [] of JSON::Any)
      quit_called.should be_true
    end

    it "registers __lune.openURL and passes the url to on_open_url" do
      fake, bridge = make_bridge
      opened_url = ""
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Lifecycle.new(
        on_quit: -> { },
        on_open_url: ->(url : String) { opened_url = url; nil }
      ))
      bridge.register_bindings(app.bindings)

      fake.invoke("runtime.__lune.openURL", "seq-2", [JSON::Any.new("https://example.com")])

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
      app.install(Lune::Runtime::Bindings::Lifecycle.new(on_quit: -> { }, debug: true))
      bridge.register_bindings(app.bindings)

      fake.invoke("runtime.__lune.environment", "seq-3", [] of JSON::Any)
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
      app.install(Lune::Runtime::Bindings::Lifecycle.new(on_quit: -> { }, debug: false))
      bridge.register_bindings(app.bindings)

      fake.invoke("runtime.__lune.environment", "seq-4", [] of JSON::Any)
      env = JSON.parse(fake.resolve_calls[0][2])
      env["debug"].as_bool.should be_false
    end

    it "returns a known os value" do
      fake, bridge = make_bridge
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Lifecycle.new(on_quit: -> { }))
      bridge.register_bindings(app.bindings)

      fake.invoke("runtime.__lune.environment", "seq-5", [] of JSON::Any)
      env = JSON.parse(fake.resolve_calls[0][2])
      ["darwin", "linux", "windows"].should contain(env["os"].as_s)
    end
  end

  describe Lune::Runtime::Bindings::Filesystem do
    it "__lune.homeDir resolves and matches Path.home" do
      fake, bridge = make_bridge
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Filesystem.new)
      bridge.register_bindings(app.bindings)

      fake.invoke("runtime.__lune.homeDir", "seq-6", [] of JSON::Any)
      _, _, result = fake.resolve_calls[0]
      JSON.parse(result).as_s.should eq(Path.home.to_s)
    end

    it "__lune.tempDir resolves and matches Dir.tempdir" do
      fake, bridge = make_bridge
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Filesystem.new)
      bridge.register_bindings(app.bindings)

      fake.invoke("runtime.__lune.tempDir", "seq-7", [] of JSON::Any)
      _, _, result = fake.resolve_calls[0]
      JSON.parse(result).as_s.should eq(Dir.tempdir)
    end

    it "__lune.downloadsDir returns a path under the home directory" do
      fake, bridge = make_bridge
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Filesystem.new)
      bridge.register_bindings(app.bindings)

      fake.invoke("runtime.__lune.downloadsDir", "seq-8", [] of JSON::Any)
      _, _, result = fake.resolve_calls[0]
      JSON.parse(result).as_s.should start_with(Path.home.to_s)
    end

    it "__lune.appDataDir returns a non-empty string" do
      fake, bridge = make_bridge
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Filesystem.new)
      bridge.register_bindings(app.bindings)

      fake.invoke("runtime.__lune.appDataDir", "seq-9", [] of JSON::Any)
      _, _, result = fake.resolve_calls[0]
      JSON.parse(result).as_s.should_not be_empty
    end
  end

  describe Lune::Runtime::Bindings::Clipboard do
    it "__lune.clipboardRead resolves with the value returned by on_read" do
      fake, bridge = make_bridge
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Clipboard.new(
        on_read: -> : String { "clipboard content" }
      ))
      bridge.register_bindings(app.bindings)

      fake.invoke("runtime.__lune.clipboardRead", "seq-10", [] of JSON::Any)

      deadline = Time.instant + 2.seconds
      while Time.instant < deadline
        break unless fake.resolve_calls.empty?
        Fiber.yield
      end

      _, status, result = fake.resolve_calls[0]
      status.should eq(0)
      JSON.parse(result).as_s.should eq("clipboard content")
    end

    it "__lune.clipboardWrite calls on_write with the provided text and resolves" do
      fake, bridge = make_bridge
      written = ""
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Clipboard.new(
        on_write: ->(text : String) { written = text; nil }
      ))
      bridge.register_bindings(app.bindings)

      fake.invoke("runtime.__lune.clipboardWrite", "seq-11", [JSON::Any.new("hello clipboard")])

      deadline = Time.instant + 2.seconds
      while Time.instant < deadline
        break unless fake.resolve_calls.empty?
        Fiber.yield
      end

      _, status, _ = fake.resolve_calls[0]
      status.should eq(0)
      written.should eq("hello clipboard")
    end
  end

  describe ".register_stubs" do
    it "registers all runtime binding classes" do
      app = Lune::App.new
      Lune::Runtime::Bindings.register_stubs(app)

      methods = app.bindings.map(&.method)

      methods.should contain("__lune.quit")
      methods.should contain("__lune.environment")
      methods.should contain("__lune.openURL")
      methods.should contain("__lune.homeDir")
      methods.should contain("__lune.clipboardRead")
      methods.should contain("__lune.clipboardWrite")
      methods.should contain("__lune.minimize")
      methods.should contain("__lune.openFile")
      methods.should contain("__lune.trayShow")
      methods.should contain("__lune.traySetMenu")
      methods.should contain("__lune.notify")
      methods.should contain("__lune.screenInfo")
    end

    it "marks every stub binding as internal" do
      app = Lune::App.new
      Lune::Runtime::Bindings.register_stubs(app)

      app.bindings.all?(&.internal?).should be_true
    end

    it "registers 22 bindings total" do
      app = Lune::App.new
      Lune::Runtime::Bindings.register_stubs(app)

      app.bindings.size.should eq(22)
    end
  end

  describe ".filter" do
    it "returns all bindings when capabilities is nil" do
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Lifecycle.new(on_quit: -> { }))
      Lune::Runtime::Bindings.filter(app.bindings, nil).size.should eq(app.bindings.size)
    end

    it "returns only matching bindings when capabilities is set" do
      app = Lune::App.new
      app.install(
        Lune::Runtime::Bindings::Lifecycle.new(on_quit: -> { }),
        Lune::Runtime::Bindings::Clipboard.new
      )
      filtered = Lune::Runtime::Bindings.filter(app.bindings, ["quit", "clipboardRead"])
      filtered.map(&.method).should eq(["__lune.quit", "__lune.clipboardRead"])
    end

    it "returns empty array when capabilities list matches nothing" do
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Lifecycle.new(on_quit: -> { }))
      Lune::Runtime::Bindings.filter(app.bindings, [] of String).should be_empty
    end

    it "silently ignores invalid capability names and only returns real matches" do
      app = Lune::App.new
      app.install(Lune::Runtime::Bindings::Lifecycle.new(on_quit: -> { }))
      filtered = Lune::Runtime::Bindings.filter(app.bindings, ["quit", "readText", "nonexistent"])
      filtered.map(&.method).should eq(["__lune.quit"])
    end
  end
end
