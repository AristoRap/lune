require "../spec_helper"
require "../support/fake_webview"

# Webview whose `resolve` raises. Models the failure mode that triggered a
# SIGSEGV in `objc_autoreleasePoolPop` once: a Crystal exception unwinding
# through Cocoa's dispatch_async callback corrupts the autorelease-pool
# stack. The bridge's `safe_resolve` should swallow exceptions raised here.
private class RaisingResolveWebview < FakeWebview
  property raise_on_resolve : Bool = true

  def resolve(seq : String, status : Int32, result : String)
    raise "simulated resolve failure" if @raise_on_resolve
    super
  end
end

# Binding whose `to_json` raises — exercises the `error_envelope` rescue
# path indirectly by raising an exception whose `message` is fine but
# whose surrounding shape forces the envelope encoder to handle gracefully.
private class WeirdMessageError < Exception
  def initialize
    super("ok")
  end
end

private def make_binding(callback : Proc(Array(JSON::Any), JSON::Any))
  Lune::Binding.new(
    namespace: "Test",
    method: "ping",
    args: [] of String,
    return_type: "String",
    callback: callback,
    internal: false,
    async: false,
  )
end

describe "Lune::Bridge — safety barriers" do
  it "swallows a raise from wv.resolve on the success path" do
    fake = RaisingResolveWebview.new
    bridge = Lune::Bridge.new(fake)
    binding = make_binding(->(_args : Array(JSON::Any)) { JSON::Any.new("ok") })
    bridge.register_binding(binding)

    backend = CaptureBackend.new
    logger = Log.new("lune.bridge.safety", backend, :debug)
    with_logger(logger) do
      # Should not raise — the rescue barrier inside the dispatched block
      # catches the simulated failure.
      fake.invoke("Test.ping", "seq-success", [] of JSON::Any)
    end

    fake.resolve_calls.should be_empty
    backend.entries.any? { |e| e.message.includes?("Bridge reply failed") }.should be_true
  end

  it "swallows a raise from wv.resolve on the error path" do
    fake = RaisingResolveWebview.new
    bridge = Lune::Bridge.new(fake)
    binding = make_binding(->(_args : Array(JSON::Any)) { raise Lune::Error.new("validation_error", "Demo error raised from Crystal") })
    bridge.register_binding(binding)

    backend = CaptureBackend.new
    logger = Log.new("lune.bridge.safety", backend, :debug)
    with_logger(logger) do
      # Should not raise — both rescue barriers catch their respective
      # failures (the binding callback, then the resolve).
      fake.invoke("Test.ping", "seq-error", [] of JSON::Any)
    end

    fake.resolve_calls.should be_empty
    backend.entries.any? { |e| e.message.includes?("Binding execution failed") }.should be_true
    backend.entries.any? { |e| e.message.includes?("Bridge reply failed") }.should be_true
  end

  it "completes the success path when resolve does not raise" do
    fake = RaisingResolveWebview.new
    fake.raise_on_resolve = false
    bridge = Lune::Bridge.new(fake)
    binding = make_binding(->(_args : Array(JSON::Any)) { JSON::Any.new("ok") })
    bridge.register_binding(binding)

    fake.invoke("Test.ping", "seq-ok", [] of JSON::Any)

    fake.resolve_calls.size.should eq(1)
    seq, status, result = fake.resolve_calls.first
    seq.should eq("seq-ok")
    status.should eq(0)
    JSON.parse(result).as_s.should eq("ok")
  end
end
