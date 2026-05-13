require "../spec_helper"

describe "Bridge races" do
  it "bind_async resolves each sequence exactly once under concurrency" do
    fake = FakeWebview.new

    bridge = Lune::Bridge.new(fake)

    binding = Lune::BindingDef.new(
      name: "echo",
      namespace: "test",
      args: [] of String,
      return_type: "JSON",
      callback: ->(args : Array(JSON::Any)) : JSON::Any {
        JSON::Any.new(args[0].as_s)
      },
      internal: false,
      async: true
    )

    bridge.register_bindings([binding])

    seqs = (0...80).map { |i| "seq-#{i}" }

    seqs.each do |seq|
      fake.invoke("test.echo", seq, [JSON::Any.new(seq)])
    end

    deadline = Time.instant + 2.seconds
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

    bridge = Lune::Bridge.new(fake)

    gate = Channel(Nil).new
    pending = 30

    binding = Lune::BindingDef.new(
      name: "slow",
      namespace: "test",
      args: [] of String,
      return_type: "JSON",
      callback: ->(args : Array(JSON::Any)) : JSON::Any {
        gate.receive
        JSON::Any.new(args[0].as_i)
      },
      internal: false,
      async: true
    )

    bridge.register_bindings([binding])

    pending.times do |i|
      fake.invoke("test.slow", "seq-#{i}", [JSON::Any.new(i.to_i64)])
    end

    sleep 10.milliseconds
    bridge.close!

    pending.times { gate.send(nil) }
    sleep 40.milliseconds

    fake.dispatch_count.should eq(0)
    fake.resolve_calls.should be_empty
  end
end
