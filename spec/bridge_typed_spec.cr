require "./spec_helper"

private class TypedFakeWebview
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

describe "Bridge typed bindings" do
  it "bind_typed with a primitive arg converts input and output" do
    fake = TypedFakeWebview.new
    bridge = Lune::Bridge.new(fake)

    bridge.bind_typed("inc", Int32) { |n| n + 1 }
    fake.invoke("inc", "seq-1", [JSON::Any.new(41_i64)])

    seq, status, result = fake.resolve_calls[0]
    seq.should eq("seq-1")
    status.should eq(0)
    JSON.parse(result).as_i.should eq(42)
  end

  it "bind_typed returns error on wrong arity" do
    fake = TypedFakeWebview.new
    bridge = Lune::Bridge.new(fake)

    bridge.bind_typed("inc", Int32) { |n| n + 1 }
    fake.invoke("inc", "seq-2", [] of JSON::Any)

    _seq, status, result = fake.resolve_calls[0]
    status.should eq(1)
    JSON.parse(result)["error"].as_s.includes?("Expected 1 argument").should be_true
  end
end
