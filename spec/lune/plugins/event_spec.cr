require "../../spec_helper"
require "../../support/fake_webview"

describe Lune::Event do
  describe "#emit" do
    it "returns Nil when no bridge is wired" do
      app = Lune::App.new
      app.event.emit("foo", "bar").should be_nil
    end

    it "returns Nil when a bridge is wired (no leak of internal each result)" do
      app = Lune::App.new
      app.bridge = Lune::Bridge.new(FakeWebview.new)
      app.event.emit("foo", "bar").should be_nil
    end
  end

  describe "boot queue" do
    it "holds emits until mark_ready is called, then flushes in order" do
      app = Lune::App.new
      fwv = FakeWebview.new
      app.bridge = Lune::Bridge.new(fwv)

      app.event.emit("deep_link", {"url" => "lune://test/1"})
      app.event.emit("deep_link", {"url" => "lune://test/2"})

      fwv.eval_calls.should be_empty

      app.event.mark_ready

      fwv.eval_calls.size.should eq(2)
      fwv.eval_calls[0].should contain(%("deep_link"))
      fwv.eval_calls[0].should contain(%(lune://test/1))
      fwv.eval_calls[1].should contain(%(lune://test/2))
    end

    it "dispatches immediately for emits issued after mark_ready" do
      app = Lune::App.new
      fwv = FakeWebview.new
      app.bridge = Lune::Bridge.new(fwv)

      app.event.mark_ready
      app.event.emit("foo", "bar")

      fwv.eval_calls.size.should eq(1)
    end

    it "mark_ready is idempotent — second call does not re-flush" do
      app = Lune::App.new
      fwv = FakeWebview.new
      app.bridge = Lune::Bridge.new(fwv)

      app.event.emit("foo", 1)
      app.event.mark_ready
      fwv.eval_calls.size.should eq(1)

      app.event.mark_ready
      fwv.eval_calls.size.should eq(1)
    end

    it "caps the pending queue and drops oldest on overflow" do
      app = Lune::App.new
      fwv = FakeWebview.new
      app.bridge = Lune::Bridge.new(fwv)

      cap = Lune::Event::PENDING_MAX
      (cap + 5).times { |i| app.event.emit("e", i) }
      app.event.mark_ready

      fwv.eval_calls.size.should eq(cap)
      # Oldest 5 entries dropped; first kept is i=5, last is i=cap+4
      fwv.eval_calls.first.should contain(%("e",5))
      fwv.eval_calls.last.should contain(%("e",#{cap + 4}))
    end
  end
end
