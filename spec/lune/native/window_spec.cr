require "../../spec_helper"

describe Lune::Native::Window do
  before_each { Lune::Native::WindowMock.reset }

  handle = Pointer(Void).null

  describe ".minimize" do
    it "delegates to the native layer" do
      Lune::Native::Window.minimize(handle)
      Lune::Native::WindowMock.calls.should contain(:minimize)
    end
  end

  describe ".maximize" do
    it "delegates to the native layer" do
      Lune::Native::Window.maximize(handle)
      Lune::Native::WindowMock.calls.should contain(:maximize)
    end
  end

  describe ".center" do
    it "delegates to the native layer" do
      Lune::Native::Window.center(handle)
      Lune::Native::WindowMock.calls.should contain(:center)
    end
  end

  describe ".set_title" do
    it "forwards the title to the native layer" do
      Lune::Native::Window.set_title(handle, "Hello")
      Lune::Native::WindowMock.calls.should contain(:set_title)
      Lune::Native::WindowMock.last_title.should eq("Hello")
    end
  end

  describe ".set_size" do
    it "forwards width and height to the native layer" do
      Lune::Native::Window.set_size(handle, 1280, 800)
      Lune::Native::WindowMock.calls.should contain(:set_size)
      Lune::Native::WindowMock.last_size.should eq({1280, 800})
    end
  end
end
