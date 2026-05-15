require "../spec_helper"

describe Lune::WindowState do
  describe ".app_name" do
    it "lowercases and hyphenates the title" do
      Lune::WindowState.app_name("My App").should eq("my-app")
    end

    it "strips non-alphanumeric characters" do
      Lune::WindowState.app_name("Hello World!").should eq("hello-world")
    end

    it "collapses multiple spaces into a single hyphen" do
      Lune::WindowState.app_name("Hello   World").should eq("hello-world")
    end

    it "returns 'lune' when the result would be empty" do
      Lune::WindowState.app_name("!!!").should eq("lune")
    end

    it "leaves already-valid names untouched" do
      Lune::WindowState.app_name("my-app").should eq("my-app")
    end
  end

  describe ".path" do
    it "ends with window.json" do
      Lune::WindowState.path("my-app").should end_with("window.json")
    end

    it "includes the app name in the path" do
      Lune::WindowState.path("my-app").should contain("my-app")
    end
  end

  describe ".save_to and .load_from" do
    it "round-trips x, y, width, height through the filesystem" do
      with_tempdir do |tmpdir|
        file_path = File.join(tmpdir, "window.json")
        Lune::WindowState.save_to(file_path, 100, 200, 1280, 720)
        result = Lune::WindowState.load_from(file_path)

        result.should_not be_nil
        r = result.not_nil!
        r[:x].should eq(100)
        r[:y].should eq(200)
        r[:width].should eq(1280)
        r[:height].should eq(720)
      end
    end

    it "returns nil when the file does not exist" do
      with_tempdir do |tmpdir|
        Lune::WindowState.load_from(File.join(tmpdir, "missing.json")).should be_nil
      end
    end

    it "returns nil on malformed JSON" do
      with_tempdir do |tmpdir|
        file_path = File.join(tmpdir, "window.json")
        File.write(file_path, "not json at all")
        Lune::WindowState.load_from(file_path).should be_nil
      end
    end

    it "creates parent directories automatically" do
      with_tempdir do |tmpdir|
        file_path = File.join(tmpdir, "nested", "dir", "window.json")
        Lune::WindowState.save_to(file_path, 0, 0, 800, 600)
        File.exists?(file_path).should be_true
      end
    end
  end
end
