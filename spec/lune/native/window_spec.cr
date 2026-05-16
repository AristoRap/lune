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

  describe ".set_titlebar_transparent" do
    it "records the call" do
      Lune::Native::Window.set_titlebar_transparent(handle, false)
      Lune::Native::WindowMock.calls.should contain(:set_titlebar_transparent)
    end

    it "records full_size_content=false" do
      Lune::Native::Window.set_titlebar_transparent(handle, false)
      Lune::Native::WindowMock.last_full_size_content.should be_false
    end

    it "records full_size_content=true" do
      Lune::Native::Window.set_titlebar_transparent(handle, true)
      Lune::Native::WindowMock.last_full_size_content.should be_true
    end
  end

  describe ".set_background_transparent" do
    it "records the call" do
      Lune::Native::Window.set_background_transparent(handle)
      Lune::Native::WindowMock.calls.should contain(:set_background_transparent)
    end
  end

  describe ".setup_drag_monitor" do
    it "records the call" do
      Lune::Native::Window.setup_drag_monitor
      Lune::Native::WindowMock.calls.should contain(:setup_drag_monitor)
    end
  end

  describe ".start_window_drag" do
    it "records the call" do
      Lune::Native::Window.start_window_drag(handle)
      Lune::Native::WindowMock.calls.should contain(:start_window_drag)
    end
  end

  describe ".hide_title" do
    it "records the call" do
      Lune::Native::Window.hide_title(handle)
      Lune::Native::WindowMock.calls.should contain(:hide_title)
    end
  end

  describe ".set_appearance" do
    it "records the call with the mode value" do
      Lune::Native::Window.set_appearance(handle, 1)
      Lune::Native::WindowMock.calls.should contain(:set_appearance)
      Lune::Native::WindowMock.last_appearance.should eq(1)
    end
  end

  describe ".set_content_protection" do
    it "records the call" do
      Lune::Native::Window.set_content_protection(handle, true)
      Lune::Native::WindowMock.calls.should contain(:set_content_protection)
    end
  end

  describe ".set_always_on_top" do
    it "records the call" do
      Lune::Native::Window.set_always_on_top(handle, true)
      Lune::Native::WindowMock.calls.should contain(:set_always_on_top)
    end
  end
end
