require "../spec_helper"

describe Lune::MacOptions do
  describe "defaults" do
    it "titlebar_transparent is false" do
      Lune::MacOptions.new.titlebar_transparent.should be_false
    end

    it "full_size_content is false" do
      Lune::MacOptions.new.full_size_content.should be_false
    end

    it "transparent is false" do
      Lune::MacOptions.new.transparent.should be_false
    end

    it "drag_zone is empty" do
      Lune::MacOptions.new.drag_zone.should be_empty
    end

    it "drag_value defaults to drag" do
      Lune::MacOptions.new.drag_value.should eq("drag")
    end
  end

  describe "via opts.mac" do
    it "is accessible from Options" do
      opts = Lune::Options.new
      opts.mac.should be_a(Lune::MacOptions)
    end

    it "mutations on opts.mac are retained" do
      opts = Lune::Options.new
      opts.mac.titlebar_transparent = true
      opts.mac.full_size_content = true
      opts.mac.drag_zone = "--lune-draggable"
      opts.mac.drag_value = "drag"

      opts.mac.titlebar_transparent.should be_true
      opts.mac.full_size_content.should be_true
      opts.mac.drag_zone.should eq("--lune-draggable")
      opts.mac.drag_value.should eq("drag")
    end
  end
end
