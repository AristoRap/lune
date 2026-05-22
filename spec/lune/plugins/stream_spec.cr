require "../../spec_helper"

describe Lune::Plugins::Stream do
  describe "#name" do
    it "is stream" do
      Lune::Plugins::Stream.new.name.should eq("stream")
    end
  end

  describe "#binding_namespace" do
    it "is Stream" do
      Lune::Plugins::Stream.new.binding_namespace.should eq("Stream")
    end
  end

  describe "#js_helpers" do
    it "includes on" do
      Lune::Plugins::Stream.new.js_helpers.should contain("on(name, cb)")
    end

    it "includes once" do
      Lune::Plugins::Stream.new.js_helpers.should contain("once(name, cb)")
    end

    it "includes off" do
      Lune::Plugins::Stream.new.js_helpers.should contain("off(name, cb)")
    end

    it "includes send" do
      Lune::Plugins::Stream.new.js_helpers.should contain("send(name, data)")
    end
  end

  describe "#dts_helpers" do
    it "includes on signature" do
      Lune::Plugins::Stream.new.dts_helpers.should contain("on(name: string")
    end

    it "includes once signature" do
      Lune::Plugins::Stream.new.dts_helpers.should contain("once(name: string")
    end

    it "includes off signature" do
      Lune::Plugins::Stream.new.dts_helpers.should contain("off(name: string")
    end

    it "includes send signature" do
      Lune::Plugins::Stream.new.dts_helpers.should contain("send(name: string")
    end
  end
end
