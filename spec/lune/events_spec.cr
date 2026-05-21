require "../spec_helper"
require "./../support/fake_webview"

describe Lune::Events do
  describe "#emit" do
    it "returns Nil when no bridge is wired" do
      app = Lune::App.new
      app.events.emit("foo", "bar").should be_nil
    end

    it "returns Nil when a bridge is wired (no leak of internal each result)" do
      app = Lune::App.new
      app.bridge = Lune::Bridge.new(FakeWebview.new)
      app.events.emit("foo", "bar").should be_nil
    end
  end
end
