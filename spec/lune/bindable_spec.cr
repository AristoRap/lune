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

# No annotation: a `JSON::Serializable` struct returned by a binding is captured
# into a named `interface` automatically (Phase 1b — vow auto-capture).
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

# A struct whose field is another serializable struct — proves transitive
# capture (both interfaces emitted, the outer referencing the inner by name).
private struct Wrapper
  include JSON::Serializable
  getter inner : DemoCounterState
  getter tag : String

  def initialize(@inner, @tag)
  end
end

private class NestedModule
  include Lune::Bindable

  @[Lune::Bind]
  def wrapped : Wrapper
    Wrapper.new(DemoCounterState.new(0, 1, ["a"]), "t")
  end
end

# A NamedTuple alias used as a binding *argument* type — the shape the Dialogs
# (`Array(FileFilter)`) and Tray (`Array(TrayMenuItem)`) plugins rely on. The
# macro must expand the alias to its NamedTuple form so the generator inlines it
# as a TS object type; a bare alias identifier would otherwise hit vow's strict
# mapper and raise `UnmappableType`.
private alias PickFilter = NamedTuple(name: String, extensions: Array(String))

private class PickerModule
  include Lune::Bindable

  @[Lune::Bind]
  def pick(filters : Array(PickFilter)) : String
    filters.map(&.[:name]).join(",")
  end
end

describe "Lune::Bindable + App bindings" do
  it "deserializes a JSON::Serializable struct arg and returns the correct result" do
    fake = FakeWebview.new

    app = Lune::App.new
    app.install(MathModule.new)
    bridge = Lune::Bridge.new(fake, app.registry)
    bridge.register_bindings(app.bindings)

    fake.invoke("MathModule.add", "seq-1", [JSON.parse(%q({"args": {"a": 3, "b": 4}}))])

    fake.resolve_calls.size.should eq(1)
    _seq, status, result = fake.resolve_calls[0]
    status.should eq(0)
    JSON.parse(result).as_i.should eq(7)
  end

  it "returns an error when a struct arg has the wrong shape" do
    fake = FakeWebview.new

    app = Lune::App.new
    app.install(MathModule.new)
    bridge = Lune::Bridge.new(fake, app.registry)
    bridge.register_bindings(app.bindings)

    fake.invoke("MathModule.add", "seq-2", [JSON.parse(%q({"args": {"x": 1}}))])

    fake.resolve_calls.size.should eq(1)
    _seq, status, _result = fake.resolve_calls[0]
    status.should eq(1)
  end

  it "returns an error when arg count does not match" do
    fake = FakeWebview.new

    app = Lune::App.new
    app.install(MathModule.new)
    bridge = Lune::Bridge.new(fake, app.registry)
    bridge.register_bindings(app.bindings)

    fake.invoke("MathModule.add", "seq-3", [] of JSON::Any)

    fake.resolve_calls.size.should eq(1)
    _seq, status, result = fake.resolve_calls[0]
    status.should eq(1)
    JSON.parse(result)["error"].as_s.should contain("missing required argument args")
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
    b.to_dts_sig.should eq("  greet(args: { msg: string }): Promise<string>;")
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

  it "captures an enum return as a string-union type alias from its serialized values (via vow)" do
    app = Lune::App.new
    app.install(StatusModule.new)

    # vow captures the enum generically (no lune-side enum logic): members are
    # the values each one serializes to (Crystal's default lowercases +
    # underscores), referenced by name in the stub and emitted as a `type` alias.
    t = app.manifest.types.find { |ty| ty.name == "DemoStatus" }.not_nil!
    t.kind.should eq("enum")
    t.members.should eq(["pending", "running", "done", "two_words"])

    known = Lune::Generator.known_types(app.manifest.types)
    b = app.bindings.first
    b.to_dts_sig(known).should eq("  current(args?: {}): Promise<DemoStatus>;")

    dts = Lune::Generator.generate_app_dts(
      app.bindings.reject(&.internal?),
      known: known,
      types: app.user_types,
    )
    dts.includes?(%(export type DemoStatus = "pending" | "running" | "done" | "two_words";)).should be_true
    dts.includes?("export interface DemoStatus").should be_false
  end

  describe "automatic struct interface capture" do
    it "maps a struct return to its named interface via the manifest's known types" do
      app = Lune::App.new
      app.install(TsTypeModule.new)

      known = Lune::Generator.known_types(app.manifest.types)
      b = app.bindings.first
      b.to_dts_sig(known).should eq("  state(args?: {}): Promise<DemoCounterState>;")
    end

    it "captures the returned struct's fields into the manifest" do
      app = Lune::App.new
      app.install(TsTypeModule.new)

      t = app.manifest.types.find { |ty| ty.name == "DemoCounterState" }.not_nil!
      t.fields.map(&.name).should eq(["value", "step", "labels"])
      t.fields.map(&.type).should eq(["Int32", "Int32", "Array(String)"])
    end

    it "emits exactly one export interface block (no double-emission)" do
      app = Lune::App.new
      app.install(TsTypeModule.new)

      # TsTypeModule is a user class, so its interface lands in App.d.ts.
      dts = Lune::Generator.generate_app_dts(
        app.bindings.reject(&.internal?),
        known: Lune::Generator.known_types(app.manifest.types),
        types: app.user_types,
      )
      dts.scan(/export interface DemoCounterState \{/).size.should eq(1)
      dts.includes?("value: number;").should be_true
      dts.includes?("step: number;").should be_true
      dts.includes?("labels: string[];").should be_true
    end

    it "captures nested serializable structs transitively" do
      app = Lune::App.new
      app.install(NestedModule.new)

      app.manifest.types.map(&.name).sort.should eq(["DemoCounterState", "Wrapper"])

      dts = Lune::Generator.generate_app_dts(
        app.bindings.reject(&.internal?),
        known: Lune::Generator.known_types(app.manifest.types),
        types: app.user_types,
      )
      dts.includes?("export interface Wrapper {").should be_true
      dts.includes?("inner: DemoCounterState;").should be_true
      dts.includes?("export interface DemoCounterState {").should be_true
    end

    it "resolves a struct argument to its interface name rather than raising" do
      app = Lune::App.new
      app.install(MathModule.new) # add(args : AddArgs) : Int32

      known = Lune::Generator.known_types(app.manifest.types)
      b = app.bindings.first
      b.to_dts_sig(known).should eq("  add(args: { args: AddArgs }): Promise<number>;")
    end

    it "inlines an aliased NamedTuple arg as a TS object type rather than raising" do
      app = Lune::App.new
      app.install(PickerModule.new) # pick(filters : Array(PickFilter)) : String

      b = app.bindings.first
      b.to_dts_sig.should eq("  pick(args: { filters: { name: string; extensions: string[] }[] }): Promise<string>;")
    end
  end
end
