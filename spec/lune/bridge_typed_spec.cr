require "../spec_helper"

private class TypedFakeWebview
  include Webview::WebviewLike

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

# Register a procedure into a fresh registry AND build a matching Binding, then
# wire both onto the fake webview through a Bridge. The Bridge dispatches by id
# through the registry (the binding only supplies id/async), so the same
# callback backs both. This mirrors how the Bindable macro wires real plugins.
private def wire(fake, namespace : String, method : String, args : Array(String), return_type : String, async : Bool = false, &cb : Hash(String, JSON::Any), ::Vow::Context? -> JSON::Any) : Nil
  registry = Vow::Registry.new
  binding = Lune::Binding.new(
    namespace: namespace,
    method: method,
    args: args,
    return_type: return_type,
    callback: cb,
    async: async,
  )
  registry.register(binding.id, &cb)
  bridge = Lune::Bridge.new(fake, registry)
  bridge.register_bindings([binding])
end

describe "Bridge typed bindings" do
  it "decodes a named arg and encodes the result" do
    fake = TypedFakeWebview.new
    wire(fake, "test", "inc", ["Int32"], "Int32") do |args, _ctx|
      n = Vow::Registry.decode(Int32, args["n"])
      JSON::Any.new((n + 1).to_i64)
    end

    fake.invoke("test.inc", "seq-1", [JSON.parse(%({"n": 41}))])

    fake.resolve_calls.size.should eq(1)
    seq, status, result = fake.resolve_calls[0]
    seq.should eq("seq-1")
    status.should eq(0)
    JSON.parse(result).as_i.should eq(42)
  end

  it "maps a missing required arg to the bad_input envelope" do
    fake = TypedFakeWebview.new
    wire(fake, "test", "inc", ["Int32"], "Int32") do |args, _ctx|
      raise Vow::Error.bad_input("missing required argument n") unless args.has_key?("n")
      JSON::Any.new((Vow::Registry.decode(Int32, args["n"]) + 1).to_i64)
    end

    fake.invoke("test.inc", "seq-2", [JSON.parse("{}")])

    fake.resolve_calls.size.should eq(1)
    _seq, status, result = fake.resolve_calls[0]
    status.should eq(1)
    body = JSON.parse(result)
    body["code"].as_s.should eq("bad_input")
    body["error"].as_s.should contain("missing required argument n")
  end

  it "maps a generic exception to code \"error\"" do
    fake = TypedFakeWebview.new
    wire(fake, "test", "boom", [] of String, "Nil") do |_args, _ctx|
      raise "something went wrong"
    end

    fake.invoke("test.boom", "seq-3", [] of JSON::Any)

    _seq, status, result = fake.resolve_calls[0]
    status.should eq(1)
    body = JSON.parse(result)
    body["code"].as_s.should eq("error")
    body["error"].as_s.should contain("something went wrong")
  end

  it "uses a Lune::Error subclass's code in the error envelope" do
    fake = TypedFakeWebview.new
    wire(fake, "test", "notfound", [] of String, "Nil") do |_args, _ctx|
      raise Lune::Error.new("not_found", "record 42 not found")
    end

    fake.invoke("test.notfound", "seq-4", [] of JSON::Any)

    _seq, status, result = fake.resolve_calls[0]
    status.should eq(1)
    body = JSON.parse(result)
    body["code"].as_s.should eq("not_found")
    body["error"].as_s.should eq("record 42 not found")
  end

  it "dispatches an async binding by name through the registry" do
    fake = TypedFakeWebview.new
    wire(fake, "test", "doubler", ["Int32"], "Int32", async: true) do |args, _ctx|
      JSON::Any.new((Vow::Registry.decode(Int32, args["n"]) * 2).to_i64)
    end

    fake.invoke("test.doubler", "seq-async", [JSON.parse(%({"n": 21}))])

    # The async pool resolves on its own fiber; yield until the reply lands.
    while fake.resolve_calls.empty?
      Fiber.yield
    end

    _seq, status, result = fake.resolve_calls[0]
    status.should eq(0)
    JSON.parse(result).as_i.should eq(42)
  end
end
