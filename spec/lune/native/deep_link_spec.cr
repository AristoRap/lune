require "../../spec_helper"

private def make_bridge
  fake = FakeWebview.new
  bridge = Lune::Bridge.new(fake)
  {fake, bridge}
end

describe Lune::Native::DeepLink do
  before_each { Lune::Native::DeepLinkMock.reset }

  describe ".install" do
    it "registers a handler that receives simulated URLs" do
      received = nil
      Lune::Native::DeepLink.install { |url| received = url }
      Lune::Native::DeepLinkMock.simulate("myapp://some/path")
      received.should eq("myapp://some/path")
    end

    it "replaces the handler on repeated installs" do
      first = nil
      second = nil
      Lune::Native::DeepLink.install { |url| first = url }
      Lune::Native::DeepLink.install { |url| second = url }
      Lune::Native::DeepLinkMock.simulate("myapp://x")
      first.should be_nil
      second.should eq("myapp://x")
    end

    it "does nothing when simulate is called before any handler is installed" do
      Lune::Native::DeepLinkMock.simulate("myapp://x")
    end
  end
end

describe Lune::Plugins::DeepLink do
  before_each { Lune::Native::DeepLinkMock.reset }

  it "forwards native deep link events to the app bridge" do
    fake, bridge = make_bridge
    app = Lune::App.new
    app.bridge = bridge

    before = fake.dispatch_count
    app.install(Lune::Plugins::DeepLink.new)
    Lune::Native::DeepLinkMock.simulate("myapp://open/path")
    fake.dispatch_count.should be > before
  end
end
