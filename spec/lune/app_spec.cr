require "../spec_helper"

describe Lune::App do
  describe "#initialize" do
    it "initializes with no bindings" do
      app = Lune::App.new

      app.bindings.should be_empty
    end

    it "initializes with no bridge" do
      app = Lune::App.new

      app.bridge.should be_nil
    end
  end

  describe "#install" do
    it "installs a single module" do
      app = Lune::App.new

      mod = MockInstallable.new
      app.install(mod)

      mod.installed_with.should eq(app)
    end

    it "installs multiple modules" do
      app = Lune::App.new

      mod1 = MockInstallable.new
      mod2 = MockInstallable.new

      app.install(mod1, mod2)

      mod1.installed_with.should eq(app)
      mod2.installed_with.should eq(app)
    end
  end

  describe "#register" do
    it "adds a binding definition" do
      app = Lune::App.new

      app.register(Lune::Binding.new(
        namespace: "math",
        method: "sum",
        args: ["a", "b"],
        return_type: "number",
        callback: ->(args : Array(JSON::Any)) { JSON::Any.new(args[0].as_i + args[1].as_i) },
      ))

      app.bindings.size.should eq(1)

      binding = app.bindings.first

      binding.method.should eq("sum")
      binding.namespace.should eq("math")
      binding.args.should eq(["a", "b"])
      binding.return_type.should eq("number")
      binding.async.should be_false
    end

    it "stores async bindings" do
      app = Lune::App.new

      app.register(Lune::Binding.new(
        namespace: "api",
        method: "fetch",
        args: ["url"],
        return_type: "object",
        async: true,
        callback: ->(_a : Array(JSON::Any)) { JSON.parse(%({"ok": true})) },
      ))

      app.bindings.first.async.should be_true
    end

    it "stores the callback block" do
      app = Lune::App.new

      app.register(Lune::Binding.new(
        namespace: "util",
        method: "echo",
        args: ["value"],
        return_type: "string",
        callback: ->(args : Array(JSON::Any)) { JSON::Any.new(args.first.as_s) },
      ))

      binding = app.bindings.first

      result = binding.callback.call([
        JSON::Any.new("hello"),
      ])

      result.as_s.should eq("hello")
    end

    it "accepts a pre-built internal binding directly" do
      app = Lune::App.new

      rb = Lune::Binding.new(
        namespace: "Test",
        method: "test.ping",
        args: [] of String,
        return_type: "String",
        callback: ->(_a : Array(JSON::Any)) { JSON::Any.new("ok") },
        internal: true,
      )

      app.register(rb)

      app.bindings.size.should eq(1)
      app.bindings.first.method.should eq("test.ping")
      app.bindings.first.internal?.should be_true
    end
  end

  describe "#event" do
    describe "#emit" do
      it "emits an event through the bridge" do
        app = Lune::App.new
        bridge = MockBridge.new

        app.bridge = bridge
        app.event.mark_ready

        app.event.emit("ready", {status: "ok"})

        bridge.last_eval.should contain("window.__lune.crystalEmit")
        bridge.last_eval.should contain("ready")
        bridge.last_eval.should contain(%("status":"ok"))
      end

      it "emits null when no data is provided" do
        app = Lune::App.new
        bridge = MockBridge.new

        app.bridge = bridge
        app.event.mark_ready

        app.event.emit("ready")

        bridge.last_eval.should contain("null")
      end
    end

    describe "#on" do
      it "registers a handler that fires when dispatch is called" do
        app = Lune::App.new
        received = [] of JSON::Any

        app.event.on("ping") { |data| received << data }
        app.event.dispatch("ping", JSON::Any.new("hello"))

        received.size.should eq(1)
        received.first.as_s.should eq("hello")
      end

      it "registers multiple handlers for the same event" do
        app = Lune::App.new
        count = 0

        app.event.on("ping") { |_| count += 1 }
        app.event.on("ping") { |_| count += 1 }
        app.event.dispatch("ping", JSON::Any.new(nil))

        count.should eq(2)
      end

      it "does not fire for a different event name" do
        app = Lune::App.new
        fired = false

        app.event.on("ping") { |_| fired = true }
        app.event.dispatch("pong", JSON::Any.new(nil))

        fired.should be_false
      end

      it "keeps firing on repeated dispatches" do
        app = Lune::App.new
        count = 0

        app.event.on("tick") { |_| count += 1 }
        app.event.dispatch("tick", JSON::Any.new(nil))
        app.event.dispatch("tick", JSON::Any.new(nil))
        app.event.dispatch("tick", JSON::Any.new(nil))

        count.should eq(3)
      end
    end

    describe "#once" do
      it "fires exactly once then removes itself" do
        app = Lune::App.new
        count = 0

        app.event.once("ping") { |_| count += 1 }
        app.event.dispatch("ping", JSON::Any.new(nil))
        app.event.dispatch("ping", JSON::Any.new(nil))

        count.should eq(1)
      end

      it "passes data to the handler" do
        app = Lune::App.new
        received = [] of JSON::Any

        app.event.once("ping") { |data| received << data }
        app.event.dispatch("ping", JSON::Any.new("only-once"))

        received.first.as_s.should eq("only-once")
      end
    end

    describe "#off" do
      it "removes all persistent handlers for an event" do
        app = Lune::App.new
        count = 0

        app.event.on("ping") { |_| count += 1 }
        app.event.off("ping")
        app.event.dispatch("ping", JSON::Any.new(nil))

        count.should eq(0)
      end

      it "removes once handlers too" do
        app = Lune::App.new
        count = 0

        app.event.once("ping") { |_| count += 1 }
        app.event.off("ping")
        app.event.dispatch("ping", JSON::Any.new(nil))

        count.should eq(0)
      end

      it "does nothing for an event with no handlers" do
        app = Lune::App.new
        app.event.off("nonexistent") # must not raise
      end
    end

    describe "#dispatch" do
      it "does nothing when no handlers are registered" do
        app = Lune::App.new
        app.event.dispatch("ping", JSON::Any.new(nil)) # must not raise
      end

      it "passes raw JSON::Any to handlers" do
        app = Lune::App.new
        received = nil

        app.event.on("data") { |d| received = d }
        app.event.dispatch("data", JSON.parse(%({"x": 1})))

        received.not_nil!["x"].as_i.should eq(1)
      end
    end
  end

  describe "#eval" do
    it "delegates javascript evaluation to the bridge" do
      app = Lune::App.new
      bridge = MockBridge.new

      app.bridge = bridge

      app.eval("console.log('hello')")

      bridge.last_eval.should eq("console.log('hello')")
    end
  end

  describe "#close!" do
    it "closes the bridge" do
      app = Lune::App.new
      bridge = MockBridge.new

      app.bridge = bridge

      app.close!

      bridge.closed.should be_true
    end
  end

  # -------------------------------------------------------------------
  # Stream (WebSocket IPC)
  # -------------------------------------------------------------------

  describe "#stream" do
    describe "#send" do
      it "does nothing when no sender is set" do
        app = Lune::App.new
        app.stream.send("tick", {price: 100}) # must not raise
      end

      it "calls the sender proc with name and JSON" do
        app = Lune::App.new
        calls = [] of {String, String}
        app.stream.sender = ->(name : String, json : String) { calls << {name, json} }

        app.stream.send("tick", {price: 42})

        calls.size.should eq(1)
        calls.first[0].should eq("tick")
        calls.first[1].should contain("42")
      end

      it "serialises nil data as JSON null" do
        app = Lune::App.new
        calls = [] of {String, String}
        app.stream.sender = ->(name : String, json : String) { calls << {name, json} }

        app.stream.send("ping")

        calls.first[1].should eq("null")
      end
    end

    describe "#on" do
      it "registers a handler that fires on dispatch" do
        app = Lune::App.new
        received = [] of JSON::Any

        app.stream.on("trade") { |d| received << d }
        app.stream.dispatch("trade", JSON::Any.new("BTC"))

        received.size.should eq(1)
        received.first.as_s.should eq("BTC")
      end

      it "keeps firing on repeated dispatches" do
        app = Lune::App.new
        count = 0

        app.stream.on("tick") { |_| count += 1 }
        app.stream.dispatch("tick", JSON::Any.new(nil))
        app.stream.dispatch("tick", JSON::Any.new(nil))

        count.should eq(2)
      end

      it "does not fire for a different stream name" do
        app = Lune::App.new
        fired = false

        app.stream.on("trade") { |_| fired = true }
        app.stream.dispatch("quote", JSON::Any.new(nil))

        fired.should be_false
      end

      it "supports multiple handlers on the same name" do
        app = Lune::App.new
        count = 0

        app.stream.on("tick") { |_| count += 1 }
        app.stream.on("tick") { |_| count += 1 }
        app.stream.dispatch("tick", JSON::Any.new(nil))

        count.should eq(2)
      end
    end

    describe "#off" do
      it "removes all handlers for a name" do
        app = Lune::App.new
        count = 0

        app.stream.on("tick") { |_| count += 1 }
        app.stream.off("tick")
        app.stream.dispatch("tick", JSON::Any.new(nil))

        count.should eq(0)
      end

      it "does nothing for a name with no handlers" do
        app = Lune::App.new
        app.stream.off("nonexistent") # must not raise
      end
    end

    describe "#dispatch" do
      it "does nothing when no handlers are registered" do
        app = Lune::App.new
        app.stream.dispatch("tick", JSON::Any.new(nil)) # must not raise
      end

      it "passes the full JSON::Any payload to handlers" do
        app = Lune::App.new
        received = nil

        app.stream.on("data") { |d| received = d }
        app.stream.dispatch("data", JSON.parse(%({"price": 99})))

        received.not_nil!["price"].as_i.should eq(99)
      end
    end
  end

  describe "bridge requirements" do
    it "raises Lune::BridgeNotReadyError when calling eval without a bridge" do
      app = Lune::App.new

      expect_raises(Lune::BridgeNotReadyError) do
        app.eval("1 + 1")
      end
    end

    it "silently drops emit when bridge is not yet set" do
      app = Lune::App.new
      app.event.emit("ready") # must not raise
    end

    it "silently drops emit after bridge is closed" do
      app = Lune::App.new
      bridge = MockBridge.new
      app.bridge = bridge
      bridge.close!

      app.event.emit("after-close") # must not raise or dispatch
      bridge.last_eval.should eq("")
    end

    it "does nothing when closing without a bridge" do
      app = Lune::App.new
      app.close! # must not raise — idempotent close
    end
  end

  describe "#async" do
    it "runs the block on a separate OS thread without blocking the caller" do
      app = Lune::App.new
      started = Channel(Nil).new(1)
      gate = Channel(Nil).new

      app.async do
        started.send(nil)
        gate.receive
      end

      started.receive # proves the block is running concurrently
      gate.send(nil)
    end

    it "accepts an optional name and still runs the block" do
      app = Lune::App.new
      done = Channel(Nil).new(1)

      app.async("spec-task") { done.send(nil) }

      done.receive
    end
  end
end

# -------------------------------------------------------------------
# Test doubles
# -------------------------------------------------------------------

class MockInstallable
  include Lune::Installable

  getter installed_with : Lune::App?

  def install(app : Lune::App)
    @installed_with = app
  end
end

class MockWebview
  include Webview::WebviewLike

  getter last_eval : String = ""

  def eval(js : String)
    @last_eval = js
  end

  def dispatch(&block)
    block.call
  end

  def resolve(seq : String, status : Int32, result : String)
  end

  def bind_deferred(name : String, &block : String, Array(JSON::Any) ->)
  end
end

class MockBridge < Lune::Bridge
  getter webview

  def initialize
    @webview = MockWebview.new
    super(@webview)
  end

  def last_eval
    @webview.last_eval
  end

  def closed
    @closed.get
  end

  def close!
    super
  end
end
