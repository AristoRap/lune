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
  end
end
