require "../../spec_helper"

describe Lune::Native::Tray do
  before_each { Lune::Native::TrayMock.reset }

  describe ".show" do
    it "records a show call" do
      Lune::Native::Tray.show("/path/to/icon.png")
      Lune::Native::TrayMock.calls.should contain(:show)
    end

    it "records the icon path" do
      Lune::Native::Tray.show("/path/to/icon.png")
      Lune::Native::TrayMock.last_icon_path.should eq("/path/to/icon.png")
    end

    it "accepts an empty icon path" do
      Lune::Native::Tray.show("")
      Lune::Native::TrayMock.calls.should contain(:show)
    end

    it "stores the click callback" do
      called = false
      Lune::Native::Tray.show("", on_click: -> { called = true; nil })
      Lune::Native::TrayMock.simulate_click
      called.should be_true
    end

    it "accepts no callback" do
      Lune::Native::Tray.show("")
      Lune::Native::TrayMock.last_click_cb.should be_nil
    end
  end

  describe ".hide" do
    it "records a hide call" do
      Lune::Native::Tray.hide
      Lune::Native::TrayMock.calls.should contain(:hide)
    end
  end

  describe ".set_icon" do
    it "records a set_icon call with the path" do
      Lune::Native::Tray.set_icon("/new/icon.png")
      Lune::Native::TrayMock.calls.should contain(:set_icon)
      Lune::Native::TrayMock.last_icon_path.should eq("/new/icon.png")
    end
  end

  describe ".set_menu" do
    items = [{id: "open", label: "Open"}, {id: "---", label: ""}, {id: "quit", label: "Quit"}]

    it "records a set_menu call" do
      Lune::Native::Tray.set_menu(items)
      Lune::Native::TrayMock.calls.should contain(:set_menu)
    end

    it "records the menu items" do
      Lune::Native::Tray.set_menu(items)
      Lune::Native::TrayMock.last_menu_items.should eq(items)
    end

    it "fires the callback with the clicked item id" do
      clicked_id = ""
      Lune::Native::Tray.set_menu(items, on_menu_click: ->(id : String) { clicked_id = id; nil })
      Lune::Native::TrayMock.simulate_menu_click("quit")
      clicked_id.should eq("quit")
    end

    it "accepts no callback" do
      Lune::Native::Tray.set_menu(items)
      Lune::Native::TrayMock.last_menu_cb.should be_nil
    end
  end
end
