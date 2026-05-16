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

  describe "via opts.mac block" do
    it "is accessible from Options" do
      Lune::Options.new.mac.should be_a(Lune::MacOptions)
    end

    it "mutations via block are retained" do
      opts = Lune::Options.new
      opts.mac do |m|
        m.full_size_content = true
        m.hide_title        = true
        m.appearance        = Lune::MacAppearance::Dark
        m.content_protection = true
        m.always_on_top     = true
      end

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
