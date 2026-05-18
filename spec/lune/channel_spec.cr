require "../spec_helper"

describe Lune::Capabilities::Channel do
  describe "#name" do
    it "is channel" do
      Lune::Capabilities::Channel.new.name.should eq("channel")
    end
  end

  describe "#binding_namespace" do
    it "is Channel" do
      Lune::Capabilities::Channel.new.binding_namespace.should eq("Channel")
    end
  end

  describe "#js_helpers" do
    it "includes on" do
      Lune::Capabilities::Channel.new.js_helpers.should contain("on(name, cb)")
    end

    it "includes once" do
      Lune::Capabilities::Channel.new.js_helpers.should contain("once(name, cb)")
    end

    it "includes off" do
      Lune::Capabilities::Channel.new.js_helpers.should contain("off(name, cb)")
    end

    it "includes send" do
      Lune::Capabilities::Channel.new.js_helpers.should contain("send(name, data)")
    end
  end

  describe "#dts_helpers" do
    it "includes on signature" do
      Lune::Capabilities::Channel.new.dts_helpers.should contain("on(name: string")
    end

    it "includes once signature" do
      Lune::Capabilities::Channel.new.dts_helpers.should contain("once(name: string")
    end

    it "includes off signature" do
      Lune::Capabilities::Channel.new.dts_helpers.should contain("off(name: string")
    end

    it "includes send signature" do
      Lune::Capabilities::Channel.new.dts_helpers.should contain("send(name: string")
    end
  end
end
