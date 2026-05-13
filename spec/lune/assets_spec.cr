require "../spec_helper"

Lune::Assets.embed_dir("spec/fixtures/embed_assets")

describe Lune::Assets do
  it "registers top-level files with the correct route" do
    String.new(Lune::Assets.get("/index.html").not_nil!).should eq("fixture index\n")
  end

  it "registers nested files with the correct route" do
    String.new(Lune::Assets.get("/nested/info.txt").not_nil!).should eq("nested fixture\n")
  end

  it "returns nil for an unknown path" do
    Lune::Assets.get("/no-such-file.html").should be_nil
  end

  describe ".mime_for" do
    it "returns text/html for .html" do
      Lune::Assets.mime_for("index.html").should eq("text/html; charset=utf-8")
    end

    it "returns application/javascript for .js" do
      Lune::Assets.mime_for("app.js").should eq("application/javascript")
    end

    it "returns application/javascript for .mjs" do
      Lune::Assets.mime_for("module.mjs").should eq("application/javascript")
    end

    it "returns text/css for .css" do
      Lune::Assets.mime_for("style.css").should eq("text/css")
    end

    it "returns image/svg+xml for .svg" do
      Lune::Assets.mime_for("icon.svg").should eq("image/svg+xml")
    end

    it "returns image/png for .png" do
      Lune::Assets.mime_for("logo.png").should eq("image/png")
    end

    it "returns font/woff2 for .woff2" do
      Lune::Assets.mime_for("font.woff2").should eq("font/woff2")
    end

    it "falls back to application/octet-stream for unknown extensions" do
      Lune::Assets.mime_for("binary.xyz").should eq("application/octet-stream")
    end

    it "is case-insensitive on the extension" do
      Lune::Assets.mime_for("IMAGE.PNG").should eq("image/png")
    end
  end
end
