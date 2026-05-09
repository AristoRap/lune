require "./spec_helper"

private class FakeWebview
  include Lune::WebviewLike

  getter dispatch_count : Int32
  getter resolve_calls : Array(Tuple(String, Int32, String))

  def initialize
    @dispatch_count = 0
    @resolve_calls = [] of Tuple(String, Int32, String)
    @bindings = {} of String => Proc(String, Array(JSON::Any), Nil)
    @lock = Mutex.new
  end

  def bind_deferred(name : String, &block : String, Array(JSON::Any) -> Nil)
    @bindings[name] = block
  end

  def invoke(name : String, seq : String, args : Array(JSON::Any))
    @bindings[name].call(seq, args)
  end

  def dispatch(&block : ->)
    @lock.synchronize { @dispatch_count += 1 }
    block.call
  end

  def resolve(seq : String, status : Int32, result : String)
    @lock.synchronize { @resolve_calls << {seq, status, result} }
  end

  def eval(js : String)
    # no-op test double
  end
end

describe "Bridge races" do
  it "bind_async resolves each sequence exactly once under concurrency" do
    fake = FakeWebview.new
    app = Lune::App.new(Lune::Bridge.new(fake))

    app.bind_async("echo") do |args|
      JSON::Any.new(args[0].as_s)
    end

    seqs = (0...80).map { |i| "seq-#{i}" }
    seqs.each do |seq|
      fake.invoke("echo", seq, [JSON::Any.new(seq)])
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
    app = Lune::App.new(Lune::Bridge.new(fake))
    gate = Channel(Nil).new
    pending = 30

    app.bind_async("slow") do |args|
      gate.receive
      JSON::Any.new(args[0].as_i)
    end

    pending.times do |i|
      fake.invoke("slow", "seq-#{i}", [JSON::Any.new(i.to_i64)])
    end

    sleep 10.milliseconds
    app.close!
    pending.times { gate.send(nil) }
    sleep 40.milliseconds

    fake.dispatch_count.should eq(0)
    fake.resolve_calls.should be_empty
  end
end
