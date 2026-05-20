require "../spec_helper"

describe Lune::Options::Mac do
  describe "defaults" do
    it "full_size_content is false" do
      Lune::Options::Mac.new.full_size_content.should be_false
    end

    it "transparent is false" do
      Lune::Options::Mac.new.transparent.should be_false
    end

    it "hide_title is false" do
      Lune::Options::Mac.new.hide_title.should be_false
    end

    it "appearance defaults to Auto" do
      Lune::Options::Mac.new.appearance.should eq(Lune::Options::Mac::Appearance::Auto)
    end

    it "content_protection is false" do
      Lune::Options::Mac.new.content_protection.should be_false
    end

    it "always_on_top is false" do
      Lune::Options::Mac.new.always_on_top.should be_false
    end

    it "hide_traffic_lights is false" do
      Lune::Options::Mac.new.hide_traffic_lights.should be_false
    end

    it "menubar_mode is false" do
      Lune::Options::Mac.new.menubar_mode.should be_false
    end
  end

  describe "via opts.mac block" do
    it "is accessible from Options" do
      Lune::Options.new.mac.should be_a(Lune::Options::Mac)
    end

    it "mutations via block are retained" do
      opts = Lune::Options.new
      opts.mac do |m|
        m.full_size_content = true
        m.hide_title = true
        m.appearance = Lune::Options::Mac::Appearance::Dark
        m.content_protection = true
        m.always_on_top = true
      end

      opts.mac.full_size_content.should be_true
      opts.mac.hide_title.should be_true
      opts.mac.appearance.should eq(Lune::Options::Mac::Appearance::Dark)
      opts.mac.content_protection.should be_true
      opts.mac.always_on_top.should be_true
    end

    it "hide_traffic_lights is settable" do
      opts = Lune::Options.new
      opts.mac { |m| m.hide_traffic_lights = true }
      opts.mac.hide_traffic_lights.should be_true
    end

    it "menubar_mode is settable" do
      opts = Lune::Options.new
      opts.mac { |m| m.menubar_mode = true }
      opts.mac.menubar_mode.should be_true
    end
  end
end

describe Lune::Options::Mac::Appearance do
  it "has Auto, Dark, and Light variants" do
    Lune::Options::Mac::Appearance::Auto.value.should eq(0)
    Lune::Options::Mac::Appearance::Dark.value.should eq(1)
    Lune::Options::Mac::Appearance::Light.value.should eq(2)
  end
end
