require "../spec_helper"

describe Lune::Options do
  describe "defaults" do
    it "sets title to Lune" do
      Lune::Options.new.title.should eq("Lune")
    end

    it "sets width to 1200" do
      Lune::Options.new.width.should eq(1200)
    end

    it "sets height to 800" do
      Lune::Options.new.height.should eq(800)
    end

    it "sets hint to NONE" do
      Lune::Options.new.hint.should eq(Webview::SizeHints::NONE)
    end

    it "is resizable" do
      Lune::Options.new.resizable.should be_true
    end

    it "has no min_width" do
      Lune::Options.new.min_width.should be_nil
    end

    it "has no min_height" do
      Lune::Options.new.min_height.should be_nil
    end

    it "has no max_width" do
      Lune::Options.new.max_width.should be_nil
    end

    it "has no max_height" do
      Lune::Options.new.max_height.should be_nil
    end

    it "is not in debug mode" do
      Lune::Options.new.debug.should be_false
    end

    it "has no on_navigate callback" do
      Lune::Options.new.on_navigate.should be_nil
    end

    it "has no on_close callback" do
      Lune::Options.new.on_close.should be_nil
    end

    it "has no on_load callback" do
      Lune::Options.new.on_load.should be_nil
    end
  end

  describe "assignment" do
    it "accepts a title" do
      opts = Lune::Options.new
      opts.title = "My App"
      opts.title.should eq("My App")
    end

    it "accepts width and height" do
      opts = Lune::Options.new
      opts.width = 1920
      opts.height = 1080
      opts.width.should eq(1920)
      opts.height.should eq(1080)
    end

    it "accepts a size hint" do
      opts = Lune::Options.new
      opts.hint = Webview::SizeHints::FIXED
      opts.hint.should eq(Webview::SizeHints::FIXED)
    end

    it "accepts resizable false" do
      opts = Lune::Options.new
      opts.resizable = false
      opts.resizable.should be_false
    end

    it "accepts min dimensions" do
      opts = Lune::Options.new
      opts.min_width = 800
      opts.min_height = 600
      opts.min_width.should eq(800)
      opts.min_height.should eq(600)
    end

    it "accepts max dimensions" do
      opts = Lune::Options.new
      opts.max_width = 2560
      opts.max_height = 1440
      opts.max_width.should eq(2560)
      opts.max_height.should eq(1440)
    end

    it "accepts debug true" do
      opts = Lune::Options.new
      opts.debug = true
      opts.debug.should be_true
    end

    it "accepts an on_navigate callback and calls it with a url" do
      opts = Lune::Options.new
      received = ""
      opts.on_navigate = ->(url : String) { received = url; nil }
      opts.on_navigate.not_nil!.call("/about")
      received.should eq("/about")
    end

    it "accepts an on_close callback and calls it" do
      opts = Lune::Options.new
      called = false
      opts.on_close = -> { called = true; nil }
      opts.on_close.not_nil!.call
      called.should be_true
    end

    it "accepts an on_load callback and calls it" do
      opts = Lune::Options.new
      called = false
      opts.on_load = -> { called = true; nil }
      opts.on_load.not_nil!.call
      called.should be_true
    end

    it "accepts an on_window_ready callback and calls it with a Void*" do
      opts = Lune::Options.new
      received : Void*? = nil
      opts.on_window_ready = ->(h : Void*) { received = h; nil }
      opts.on_window_ready.not_nil!.call(Pointer(Void).null)
      received.should eq(Pointer(Void).null)
    end
  end
end

describe Lune::DropOptions do
  describe "defaults" do
    it "enabled is false" do
      Lune::DropOptions.new.enabled.should be_false
    end

    it "disable_webview_drop is false" do
      Lune::DropOptions.new.disable_webview_drop.should be_false
    end

    it "zone defaults to empty string" do
      Lune::DropOptions.new.zone.should be_empty
    end

    it "value defaults to drop" do
      Lune::DropOptions.new.value.should eq("drop")
    end

    it "has no on_drop callback" do
      Lune::DropOptions.new.on_drop.should be_nil
    end
  end

  describe "via opts.drop block" do
    it "is accessible from Options" do
      Lune::Options.new.drop.should be_a(Lune::DropOptions)
    end

    it "mutations via block are retained" do
      opts = Lune::Options.new
      opts.drop do |d|
        d.enabled = true
        d.zone = "--lune-drop-target"
        d.value = "file"
      end
      opts.drop.enabled.should be_true
      opts.drop.zone.should eq("--lune-drop-target")
      opts.drop.value.should eq("file")
    end

    it "accepts an on_drop callback and calls it with x, y, paths" do
      opts = Lune::Options.new
      received_x = 0; received_y = 0; received_paths = [] of String
      opts.drop do |d|
        d.on_drop = ->(x : Int32, y : Int32, paths : Array(String)) {
          received_x = x; received_y = y; received_paths = paths; nil
        }
      end
      opts.drop.on_drop.not_nil!.call(10, 20, ["/tmp/photo.png"])
      received_x.should eq(10)
      received_y.should eq(20)
      received_paths.should eq(["/tmp/photo.png"])
    end
  end
end

describe Lune::DragOptions do
  describe "defaults" do
    it "zone defaults to empty string" do
      Lune::DragOptions.new.zone.should be_empty
    end

    it "value defaults to drag" do
      Lune::DragOptions.new.value.should eq("drag")
    end
  end

  describe "via opts.drag block" do
    it "is accessible from Options" do
      Lune::Options.new.drag.should be_a(Lune::DragOptions)
    end

    it "mutations via block are retained" do
      opts = Lune::Options.new
      opts.drag do |d|
        d.zone = "--lune-draggable"
        d.value = "drag"
      end
      opts.drag.zone.should eq("--lune-draggable")
      opts.drag.value.should eq("drag")
    end
  end
end

describe Lune::TrayOptions do
  describe "defaults" do
    it "has no on_click callback" do
      Lune::TrayOptions.new.on_click.should be_nil
    end

    it "has no on_menu_click callback" do
      Lune::TrayOptions.new.on_menu_click.should be_nil
    end
  end

  describe "via opts.tray block" do
    it "is accessible from Options" do
      Lune::Options.new.tray.should be_a(Lune::TrayOptions)
    end

    it "mutations via block are retained" do
      opts = Lune::Options.new
      clicked = false
      opts.tray do |t|
        t.on_click = -> { clicked = true; nil }
      end
      opts.tray.on_click.not_nil!.call
      clicked.should be_true
    end
  end
end

describe "disable_context_menu on Options" do
  it "defaults to false" do
    Lune::Options.new.disable_context_menu.should be_false
  end

  it "can be enabled" do
    opts = Lune::Options.new
    opts.disable_context_menu = true
    opts.disable_context_menu.should be_true
  end
end
