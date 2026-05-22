require "../../spec_helper"

describe Lune::Native::Screen do
  before_each { Lune::Native::ScreenMock.reset }

  describe ".info" do
    it "delegates to the native layer" do
      Lune::Native::Screen.info
      Lune::Native::ScreenMock.calls.should contain(:info)
    end

    it "returns the stubbed dimensions and scale" do
      Lune::Native::ScreenMock.stub_info(2560, 1440, 2.0)
      info = Lune::Native::Screen.info
      info[:width].should eq(2560)
      info[:height].should eq(1440)
      info[:scale].should eq(2.0)
    end

    it "returns defaults of 1920x1080 @1.0 when not stubbed" do
      info = Lune::Native::Screen.info
      info[:width].should eq(1920)
      info[:height].should eq(1080)
      info[:scale].should eq(1.0)
    end
  end
end
