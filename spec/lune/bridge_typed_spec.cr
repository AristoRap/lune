require "../spec_helper"

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
    if handler = @bindings[name]?
      handler.call(seq, args)
    end
  end

  def dispatch(&block : ->)
    block.call
    nil
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

    binding = Lune::BindingDef.new(
      name: "inc",
      namespace: "test",
      args: ["Int32"],
      return_type: "Int32",
      callback: ->(args : Array(JSON::Any)) : JSON::Any {
        n = args[0].as_i.to_i32
        JSON::Any.new(n + 1)
      },
      internal: false,
      async: false
    )

    bridge.register_bindings([binding])

    fake.invoke("test.inc", "seq-1", [JSON::Any.new(41_i64)])

    fake.resolve_calls.size.should eq(1)

    seq, status, result = fake.resolve_calls[0]
    seq.should eq("seq-1")
    status.should eq(0)
    JSON.parse(result).as_i.should eq(42)
  end

  it "bind_typed returns error on wrong arity" do
    fake = TypedFakeWebview.new
    bridge = Lune::Bridge.new(fake)

    binding = Lune::BindingDef.new(
      name: "inc",
      namespace: "test",
      args: ["Int32"],
      return_type: "Int32",
      callback: ->(args : Array(JSON::Any)) : JSON::Any {
        if args.size != 1
          raise "Expected 1 argument"
        end
        n = args[0].as_i.to_i32
        JSON::Any.new(n + 1)
      },
      internal: false,
      async: false
    )

    bridge.register_bindings([binding])

    fake.invoke("test.inc", "seq-2", [] of JSON::Any)

    fake.resolve_calls.size.should eq(1)

    _seq, status, result = fake.resolve_calls[0]
    status.should eq(1)
    JSON.parse(result)["error"].as_s.should contain("Expected 1 argument")
  end

  it "generic exception produces code: \"error\" in the error envelope" do
    fake = TypedFakeWebview.new
    bridge = Lune::Bridge.new(fake)

    binding = Lune::BindingDef.new(
      name: "boom",
      namespace: "test",
      args: [] of String,
      return_type: "Nil",
      callback: ->(_args : Array(JSON::Any)) : JSON::Any {
        raise "something went wrong"
      },
      internal: false,
      async: false
    )

    bridge.register_bindings([binding])
    fake.invoke("test.boom", "seq-3", [] of JSON::Any)

    _seq, status, result = fake.resolve_calls[0]
    status.should eq(1)
    body = JSON.parse(result)
    body["code"].as_s.should eq("error")
    body["error"].as_s.should contain("something went wrong")
  end

  it "Lune::Error subclass uses its code in the error envelope" do
    fake = TypedFakeWebview.new
    bridge = Lune::Bridge.new(fake)

    binding = Lune::BindingDef.new(
      name: "notfound",
      namespace: "test",
      args: [] of String,
      return_type: "Nil",
      callback: ->(_args : Array(JSON::Any)) : JSON::Any {
        raise Lune::Error.new("not_found", "record 42 not found")
      },
      internal: false,
      async: false
    )

    bridge.register_bindings([binding])
    fake.invoke("test.notfound", "seq-4", [] of JSON::Any)

    _seq, status, result = fake.resolve_calls[0]
    status.should eq(1)
    body = JSON.parse(result)
    body["code"].as_s.should eq("not_found")
    body["error"].as_s.should eq("record 42 not found")
  end
end
