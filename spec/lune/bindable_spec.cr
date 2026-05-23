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

private enum DemoStatus
  Pending
  Running
  Done
  TwoWords
end

private class StatusModule
  include Lune::Bindable

  @[Lune::Bind]
  def current : DemoStatus
    DemoStatus::Pending
  end
end

@[Lune::TsType]
private struct DemoCounterState
  include JSON::Serializable
  getter value : Int32
  getter step : Int32
  getter labels : Array(String)

  def initialize(@value, @step, @labels)
  end
end

private class TsTypeModule
  include Lune::Bindable

  @[Lune::Bind]
  def state : DemoCounterState
    DemoCounterState.new(0, 1, ["a"])
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
    b.to_dts_sig.should eq("  greet(msg: string): Promise<string>;")
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

  it "derives a TS string union from an enum return type" do
    app = Lune::App.new
    app.install(StatusModule.new)

    b = app.bindings.first
    b.to_dts_sig.should eq(%(  current(): Promise<"pending" | "running" | "done" | "two_words">;))
  end

  describe "@[Lune::TsType] return type" do
    it "wires ts_return_type to Promise<TypeName> by simple name" do
      app = Lune::App.new
      app.install(TsTypeModule.new)

      b = app.bindings.first
      b.to_dts_sig.should eq("  state(): Promise<DemoCounterState>;")
    end

    it "registers the type's fields with Lune.register_ts_type" do
      app = Lune::App.new
      app.install(TsTypeModule.new)

      fields = Lune.registered_ts_types["DemoCounterState"]
      fields.should eq([{"value", "Int32"}, {"step", "Int32"}, {"labels", "Array(String)"}])
    end

    it "emits an export interface block in the generated d.ts" do
      app = Lune::App.new
      app.install(TsTypeModule.new)

      dts = Lune::Generator.generate_runtime_dts(app.bindings.select(&.internal?))
      # Plain bindings (internal? == false on user classes) won't surface in
      # runtime.d.ts, but the interface block is sourced from the registry and
      # appears regardless. Assert on the interface, not on the binding sig.
      dts.includes?("export interface DemoCounterState {").should be_true
      dts.includes?("value: number;").should be_true
      dts.includes?("step: number;").should be_true
      dts.includes?("labels: string[];").should be_true
    end
  end
end
