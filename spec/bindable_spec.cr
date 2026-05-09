require "./spec_helper"

private class BindableFakeWebview
  include Lune::WebviewLike

  getter resolve_calls : Array(Tuple(String, Int32, String))

  def initialize
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
  end
end

private struct AddArgs
  include JSON::Serializable
  getter a : Int32
  getter b : Int32
end

private struct GreetArgs
  include JSON::Serializable
  getter greeting : String
  getter name : String
end

describe "Bindable mixin" do
  it "bind_typed with a primitive type still works" do
    fake = BindableFakeWebview.new
    app = Lune::App.new(Lune::Bridge.new(fake))

    app.bind_typed("inc", Int32) { |n| n + 1 }
    fake.invoke("inc", "s1", [JSON::Any.new(41_i64)])

    _seq, status, result = fake.resolve_calls[0]
    status.should eq(0)
    JSON.parse(result).as_i.should eq(42)
  end

  it "bind_typed with a struct deserialises args from a single JSON object" do
    fake = BindableFakeWebview.new
    app = Lune::App.new(Lune::Bridge.new(fake))

    app.bind_typed("add", AddArgs) { |args| args.a + args.b }

    payload = JSON::Any.new({"a" => JSON::Any.new(10_i64), "b" => JSON::Any.new(32_i64)})
    fake.invoke("add", "s2", [payload])

    _seq, status, result = fake.resolve_calls[0]
    status.should eq(0)
    JSON.parse(result).as_i.should eq(42)
  end

  it "bind_typed with a struct can return a String" do
    fake = BindableFakeWebview.new
    app = Lune::App.new(Lune::Bridge.new(fake))

    app.bind_typed("greet", GreetArgs) { |args| "#{args.greeting}, #{args.name}!" }

    payload = JSON::Any.new({
      "greeting" => JSON::Any.new("Hello"),
      "name"     => JSON::Any.new("Crystal"),
    })
    fake.invoke("greet", "s3", [payload])

    _seq, status, result = fake.resolve_calls[0]
    status.should eq(0)
    JSON.parse(result).as_s.should eq("Hello, Crystal!")
  end

  it "bind_typed returns error when args.size != 1" do
    fake = BindableFakeWebview.new
    app = Lune::App.new(Lune::Bridge.new(fake))

    app.bind_typed("inc", Int32) { |n| n + 1 }
    fake.invoke("inc", "s4", [] of JSON::Any)

    _seq, status, result = fake.resolve_calls[0]
    status.should eq(1)
    JSON.parse(result)["error"].as_s.includes?("Expected 1 argument").should be_true
  end

  it "namespace yields an App scoped to that prefix" do
    fake = BindableFakeWebview.new
    app = Lune::App.new(Lune::Bridge.new(fake))

    app.namespace("math") do |ns|
      ns.bind_typed("add", AddArgs) { |args| args.a + args.b }
    end

    payload = JSON::Any.new({"a" => JSON::Any.new(5_i64), "b" => JSON::Any.new(7_i64)})
    fake.invoke("math.add", "s5", [payload])

    _seq, status, result = fake.resolve_calls[0]
    status.should eq(0)
    JSON.parse(result).as_i.should eq(12)
  end

  it "namespace is nestable — prefix composes correctly" do
    fake = BindableFakeWebview.new
    app = Lune::App.new(Lune::Bridge.new(fake))

    app.namespace("math") do |math|
      math.namespace("trig") do |trig|
        trig.bind_typed("double", Int32) { |n| n * 2 }
      end
    end

    fake.invoke("math.trig.double", "s6", [JSON::Any.new(21_i64)])

    _seq, status, result = fake.resolve_calls[0]
    status.should eq(0)
    JSON.parse(result).as_i.should eq(42)
  end
end
