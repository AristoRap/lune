require "../spec_helper"

describe "Bridge races" do
  it "bind_async resolves each sequence exactly once under concurrency" do
    fake = FakeWebview.new

    cb = ->(args : Hash(String, JSON::Any), _ctx : ::Vow::Context?) : JSON::Any {
      JSON::Any.new(args["n"].as_s)
    }

    binding = Lune::Binding.new(
      namespace: "test",
      method: "echo",
      args: [] of String,
      return_type: "JSON",
      callback: cb,
      internal: false,
      async: true
    )

    registry = Vow::Registry.new
    registry.register(binding.id, &cb)
    bridge = Lune::Bridge.new(fake, registry)
    bridge.register_bindings([binding])

    seqs = (0...80).map { |i| "seq-#{i}" }

    seqs.each do |seq|
      fake.invoke("test.echo", seq, [JSON.parse(%({"n": #{seq.to_json}}))])
    end

    deadline = Time.instant + 5.seconds
    while Time.instant < deadline
      break if fake.resolve_calls.size == seqs.size
      sleep 5.milliseconds
    end

    fake.resolve_calls.size.should eq(seqs.size)

    grouped = fake.resolve_calls.group_by(&.[0])
    grouped.size.should eq(seqs.size)
    grouped.each_value { |calls| calls.size.should eq(1) }
    fake.resolve_calls.each { |(_, status, _)| status.should eq(0) }
  end

  it "bind_async skips all late dispatches after app close" do
    fake = FakeWebview.new

    gate = Channel(Nil).new
    pending = 30

    cb = ->(args : Hash(String, JSON::Any), _ctx : ::Vow::Context?) : JSON::Any {
      gate.receive
      JSON::Any.new(args["n"].as_i)
    }

    binding = Lune::Binding.new(
      namespace: "test",
      method: "slow",
      args: [] of String,
      return_type: "JSON",
      callback: cb,
      internal: false,
      async: true
    )

    registry = Vow::Registry.new
    registry.register(binding.id, &cb)
    bridge = Lune::Bridge.new(fake, registry)
    bridge.register_bindings([binding])

    pending.times do |i|
      fake.invoke("test.slow", "seq-#{i}", [JSON.parse(%({"n": #{i}}))])
    end

    sleep 10.milliseconds
    bridge.close!

    pending.times { gate.send(nil) }
    sleep 150.milliseconds

    fake.dispatch_count.should eq(0)
    fake.resolve_calls.should be_empty
  end
end
