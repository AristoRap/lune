require "../spec_helper"

private class GreetModule
  include Lune::Bindable

  @[Lune::Bind]
  def greet(msg : String) : String
    "Hello, #{msg}!"
  end
end

private struct AddArgs
  include JSON::Serializable
  getter a : Int32
  getter b : Int32
end

private class MathModule
  include Lune::Bindable

  @[Lune::Bind]
  def add(args : AddArgs) : Int32
    args.a + args.b
  end
end

describe "Lune::Bindable + App bindings" do
  it "deserializes a JSON::Serializable struct arg and returns the correct result" do
    fake = FakeWebview.new
    bridge = Lune::Bridge.new(fake)

    app = Lune::App.new
    app.install(MathModule.new)
    bridge.register_bindings(app.bindings)

    fake.invoke("MathModule.add", "seq-1", [JSON.parse(%q({"a": 3, "b": 4}))])

    fake.resolve_calls.size.should eq(1)
    _seq, status, result = fake.resolve_calls[0]
    status.should eq(0)
    JSON.parse(result).as_i.should eq(7)
  end

  it "returns an error when a struct arg has the wrong shape" do
    fake = FakeWebview.new
    bridge = Lune::Bridge.new(fake)

    app = Lune::App.new
    app.install(MathModule.new)
    bridge.register_bindings(app.bindings)

    fake.invoke("MathModule.add", "seq-2", [JSON.parse(%q({"x": 1}))])

    fake.resolve_calls.size.should eq(1)
    _seq, status, _result = fake.resolve_calls[0]
    status.should eq(1)
  end

  it "returns an error when arg count does not match" do
    fake = FakeWebview.new
    bridge = Lune::Bridge.new(fake)

    app = Lune::App.new
    app.install(MathModule.new)
    bridge.register_bindings(app.bindings)

    fake.invoke("MathModule.add", "seq-3", [] of JSON::Any)

    fake.resolve_calls.size.should eq(1)
    _seq, status, result = fake.resolve_calls[0]
    status.should eq(1)
    JSON.parse(result)["error"].as_s.should contain("expected 1 arg(s), got 0")
  end

  it "registers bindings into App via install" do
    app = Lune::App.new

    app.install(GreetModule.new)

    app.bindings.size.should eq(1)
    app.bindings.first.method.should eq("greet")
    app.bindings.first.namespace.should eq("GreetModule")
  end

  it "captures real param names from the Crystal method signature" do
    app = Lune::App.new
    app.install(GreetModule.new)

    b = app.bindings.first
    b.to_dts_sig.should eq("  Greet(msg: string): Promise<string>;")
  end

  it "supports multiple modules in one app" do
    app = Lune::App.new

    app.install(GreetModule.new)
    app.install(MathModule.new)

    names = app.bindings.map(&.method).sort
    namespaces = app.bindings.map(&.namespace).sort

    names.should eq(["add", "greet"])
    namespaces.should eq(["GreetModule", "MathModule"])
  end

  it "does not fail when installing modules" do
    app = Lune::App.new

    app.install(GreetModule.new)
    app.install(MathModule.new)

    app.bindings.empty?.should eq(false)
  end
end
