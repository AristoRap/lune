require "./spec_helper"

private class AppFakeWebview
  include Lune::WebviewLike

  getter eval_calls : Array(String)
  getter resolve_calls : Array(Tuple(String, Int32, String))

  def initialize
    @eval_calls = [] of String
    @resolve_calls = [] of Tuple(String, Int32, String)
    @bindings = {} of String => Proc(String, Array(JSON::Any), Nil)
  end

  def bind_deferred(name : String, &block : String, Array(JSON::Any) -> Nil)
    @bindings[name] = block
  end

  def invoke(name : String, seq : String, args : Array(JSON::Any))
    @bindings[name].call(seq, args)
  end

  def dispatch(&block : ->)
    block.call
  end

  def resolve(seq : String, status : Int32, result : String)
    @resolve_calls << {seq, status, result}
  end

  def eval(js : String)
    @eval_calls << js
  end
end

private class EchoModule
  include Lune::Installable

  def install(app : Lune::App)
    app.bind_typed("echo", String) { |msg| msg }
  end
end

describe Lune::App do
  describe "#bind" do
    it "registers a sync binding and propagates the seq to resolve" do
      fake = AppFakeWebview.new
      app = Lune::App.new(Lune::Bridge.new(fake))

      app.bind("greet") { |args| JSON::Any.new("hi #{args[0].as_s}") }
      fake.invoke("greet", "seq-42", [JSON::Any.new("world")])

      seq, status, result = fake.resolve_calls[0]
      seq.should eq("seq-42")
      status.should eq(0)
      JSON.parse(result).as_s.should eq("hi world")
    end

    it "resolves errors with status 1" do
      fake = AppFakeWebview.new
      app = Lune::App.new(Lune::Bridge.new(fake))

      app.bind("boom") { |_| raise "oops" }
      fake.invoke("boom", "seq-err", [] of JSON::Any)

      _seq, status, result = fake.resolve_calls[0]
      status.should eq(1)
      JSON.parse(result)["error"].as_s.should eq("oops")
    end
  end

  describe "#install" do
    it "delegates binding registration to the Installable module" do
      fake = AppFakeWebview.new
      app = Lune::App.new(Lune::Bridge.new(fake))

      app.install(EchoModule.new)

      fake.invoke("echo", "s1", [JSON::Any.new("hello")])
      _seq, status, result = fake.resolve_calls[0]
      status.should eq(0)
      JSON.parse(result).as_s.should eq("hello")
    end
  end

  describe "#emit" do
    it "evaluates __lune_emit with the event name and serialized data" do
      fake = AppFakeWebview.new
      app = Lune::App.new(Lune::Bridge.new(fake))

      app.emit("tick", {count: 1})

      fake.eval_calls.size.should eq(1)
      fake.eval_calls[0].should contain("window.__lune_emit")
      fake.eval_calls[0].should contain(%("tick"))
      fake.eval_calls[0].should contain("count")
    end

    it "emits null when no data is provided" do
      fake = AppFakeWebview.new
      app = Lune::App.new(Lune::Bridge.new(fake))

      app.emit("ping")

      fake.eval_calls[0].should contain("null")
    end

    it "prefixes the event name with the namespace" do
      fake = AppFakeWebview.new
      app = Lune::App.new(Lune::Bridge.new(fake))

      app.namespace("hash") { |ns| ns.emit("done", "ok") }

      fake.eval_calls[0].should contain("hash.done")
    end
  end

  describe "#eval" do
    it "forwards JavaScript to the webview" do
      fake = AppFakeWebview.new
      app = Lune::App.new(Lune::Bridge.new(fake))

      app.eval("console.log('hi')")

      fake.eval_calls.should eq(["console.log('hi')"])
    end
  end

  describe "#binding_names" do
    it "returns names in registration order" do
      fake = AppFakeWebview.new
      app = Lune::App.new(Lune::Bridge.new(fake))

      app.bind("beta") { |_| JSON::Any.new(nil) }
      app.bind("alpha") { |_| JSON::Any.new(nil) }

      app.binding_names.should eq(["beta", "alpha"])
    end

    it "excludes duplicates while preserving order" do
      fake = AppFakeWebview.new
      app = Lune::App.new(Lune::Bridge.new(fake))

      app.bind("ping") { |_| JSON::Any.new(nil) }
      app.bind("pong") { |_| JSON::Any.new(nil) }
      app.bind("ping") { |_| JSON::Any.new(nil) }

      app.binding_names.should eq(["ping", "pong"])
    end

    it "includes namespace-prefixed names" do
      fake = AppFakeWebview.new
      app = Lune::App.new(Lune::Bridge.new(fake))

      app.namespace("math") do |ns|
        ns.bind("add") { |_| JSON::Any.new(nil) }
        ns.bind("sub") { |_| JSON::Any.new(nil) }
      end

      app.binding_names.should eq(["math.add", "math.sub"])
    end

    it "includes names registered via install" do
      fake = AppFakeWebview.new
      app = Lune::App.new(Lune::Bridge.new(fake))

      app.install(EchoModule.new)

      app.binding_names.should eq(["echo"])
    end
  end
end
