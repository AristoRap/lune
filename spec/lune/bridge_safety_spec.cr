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

# Build a Test.ping binding around *callback*, register the same proc into a
# fresh registry, and wire both onto *fake* through a Bridge (mirrors the
# `wire` helper in bridge_typed_spec.cr). The Bridge dispatches by id through
# the registry, so the callback backs both. Returns the wired bridge.
private def wire_binding(fake, callback : Proc(Hash(String, JSON::Any), ::Vow::Context?, JSON::Any))
  binding = Lune::Binding.new(
    namespace: "Test",
    method: "ping",
    args: [] of String,
    return_type: "String",
    callback: callback,
    internal: false,
    async: false,
  )
  registry = Vow::Registry.new
  registry.register(binding.id, &callback)
  bridge = Lune::Bridge.new(fake, registry)
  bridge.register_binding(binding)
  bridge
end

describe "Lune::Bridge — safety barriers" do
  it "swallows a raise from wv.resolve on the success path" do
    fake = RaisingResolveWebview.new
    wire_binding(fake, ->(_args : Hash(String, JSON::Any), _ctx : ::Vow::Context?) { JSON::Any.new("ok") })

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
    wire_binding(fake, ->(_args : Hash(String, JSON::Any), _ctx : ::Vow::Context?) { raise Lune::Error.new("validation_error", "Demo error raised from Crystal") })

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
    wire_binding(fake, ->(_args : Hash(String, JSON::Any), _ctx : ::Vow::Context?) { JSON::Any.new("ok") })

    fake.invoke("Test.ping", "seq-ok", [] of JSON::Any)

    fake.resolve_calls.size.should eq(1)
    seq, status, result = fake.resolve_calls.first
    seq.should eq("seq-ok")
    status.should eq(0)
    JSON.parse(result).as_s.should eq("ok")
  end
end
