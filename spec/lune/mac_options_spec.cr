require "../spec_helper"

describe Lune::MacOptions do
  describe "defaults" do
    it "full_size_content is false" do
      Lune::MacOptions.new.full_size_content.should be_false
    end

    it "transparent is false" do
      Lune::MacOptions.new.transparent.should be_false
    end

    it "hide_title is false" do
      Lune::MacOptions.new.hide_title.should be_false
    end

    it "appearance defaults to Auto" do
      Lune::MacOptions.new.appearance.should eq(Lune::MacAppearance::Auto)
    end

    it "content_protection is false" do
      Lune::MacOptions.new.content_protection.should be_false
    end

    it "always_on_top is false" do
      Lune::MacOptions.new.always_on_top.should be_false
    end
  end

  describe "via opts.mac" do
    it "is accessible from Options" do
      Lune::Options.new.mac.should be_a(Lune::MacOptions)
    end

    it "mutations are retained" do
      opts = Lune::Options.new
      opts.mac.full_size_content = true
      opts.mac.hide_title = true
      opts.mac.appearance = Lune::MacAppearance::Dark
      opts.mac.content_protection = true
      opts.mac.always_on_top = true

      opts.mac.full_size_content.should be_true
      opts.mac.hide_title.should be_true
      opts.mac.appearance.should eq(Lune::MacAppearance::Dark)
      opts.mac.content_protection.should be_true
      opts.mac.always_on_top.should be_true
    end
  end
end

describe Lune::MacAppearance do
  it "has Auto, Dark, and Light variants" do
    Lune::MacAppearance::Auto.value.should eq(0)
    Lune::MacAppearance::Dark.value.should eq(1)
    Lune::MacAppearance::Light.value.should eq(2)
  end
end

describe "drag_zone on Options" do
  it "defaults to empty string" do
    Lune::Options.new.drag_zone.should be_empty
  end

  it "drag_value defaults to drag" do
    Lune::Options.new.drag_value.should eq("drag")
  end

  it "can be set" do
    opts = Lune::Options.new
    opts.drag_zone = "--lune-draggable"
    opts.drag_value = "drag"
    opts.drag_zone.should eq("--lune-draggable")
    opts.drag_value.should eq("drag")
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
