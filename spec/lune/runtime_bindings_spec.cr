require "../spec_helper"

private def make_bridge
  fake = FakeWebview.new
  bridge = Lune::Bridge.new(fake)
  {fake, bridge}
end

describe Lune::Bindings::Runtime do
  describe ".build" do
    it "does not pollute user binding_names" do
      fake, bridge = make_bridge

      quit_called = false

      bindings = Lune::Bindings::Runtime.build(
        on_quit: -> : Nil {
          quit_called = true
          nil
        },
        debug: false
      )

      bridge.register_bindings(bindings)
      bridge.all_bindings.values.reject(&.internal).should be_empty
    end

    it "invokes on_quit when __lune.quit is called" do
      fake, bridge = make_bridge

      quit_called = false

      bindings = Lune::Bindings::Runtime.build(
        on_quit: -> : Nil {
          quit_called = true
          nil
        }
      )

      bridge.register_bindings(bindings)
      fake.invoke("runtime.__lune.quit", "seq-1", [] of JSON::Any)

      quit_called.should be_true
    end

    it "registers __lune.openURL and passes the url to on_open_url" do
      fake, bridge = make_bridge

      opened_url = ""

      bindings = Lune::Bindings::Runtime.build(
        on_quit: -> : Nil { },
        on_open_url: ->(url : String) : Nil {
          opened_url = url
          nil
        }
      )

      bridge.register_bindings(bindings)

      fake.invoke("runtime.__lune.openURL", "seq-2", [
        JSON::Any.new("https://example.com"),
      ])

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

      bindings = Lune::Bindings::Runtime.build(
        on_quit: -> : Nil { },
        debug: true
      )

      bridge.register_bindings(bindings)
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

      bindings = Lune::Bindings::Runtime.build(
        on_quit: -> : Nil { },
        debug: false
      )

      bridge.register_bindings(bindings)
      fake.invoke("runtime.__lune.environment", "seq-4", [] of JSON::Any)

      env = JSON.parse(fake.resolve_calls[0][2])
      env["debug"].as_bool.should be_false
    end

    it "returns a known os value" do
      fake, bridge = make_bridge

      bindings = Lune::Bindings::Runtime.build(
        on_quit: -> : Nil { }
      )

      bridge.register_bindings(bindings)
      fake.invoke("runtime.__lune.environment", "seq-5", [] of JSON::Any)

      env = JSON.parse(fake.resolve_calls[0][2])
      ["darwin", "linux", "windows"].should contain(env["os"].as_s)
    end

    describe "__lune.homeDir" do
      it "resolves and matches Path.home" do
        fake, bridge = make_bridge
        bridge.register_bindings(Lune::Bindings::Runtime.build(on_quit: -> : Nil { }))
        fake.invoke("runtime.__lune.homeDir", "seq-6", [] of JSON::Any)
        _, _, result = fake.resolve_calls[0]
        JSON.parse(result).as_s.should eq(Path.home.to_s)
      end
    end

    describe "__lune.tempDir" do
      it "resolves and matches Dir.tempdir" do
        fake, bridge = make_bridge
        bridge.register_bindings(Lune::Bindings::Runtime.build(on_quit: -> : Nil { }))
        fake.invoke("runtime.__lune.tempDir", "seq-7", [] of JSON::Any)
        _, _, result = fake.resolve_calls[0]
        JSON.parse(result).as_s.should eq(Dir.tempdir)
      end
    end

    describe "__lune.downloadsDir" do
      it "returns a path under the home directory" do
        fake, bridge = make_bridge
        bridge.register_bindings(Lune::Bindings::Runtime.build(on_quit: -> : Nil { }))
        fake.invoke("runtime.__lune.downloadsDir", "seq-8", [] of JSON::Any)
        _, _, result = fake.resolve_calls[0]
        JSON.parse(result).as_s.should start_with(Path.home.to_s)
      end
    end

    describe "__lune.appDataDir" do
      it "returns a non-empty string" do
        fake, bridge = make_bridge
        bridge.register_bindings(Lune::Bindings::Runtime.build(on_quit: -> : Nil { }))
        fake.invoke("runtime.__lune.appDataDir", "seq-9", [] of JSON::Any)
        _, _, result = fake.resolve_calls[0]
        JSON.parse(result).as_s.should_not be_empty
      end
    end
  end
end
