require "../spec_helper"

private def with_lune_yml(content : String, &)
  dir = File.join(Dir.tempdir, "lune_config_#{Random.new.hex(8)}")
  Dir.mkdir_p(dir)
  File.write(File.join(dir, "lune.yml"), content)
  Dir.cd(dir) { yield }
ensure
  FileUtils.rm_rf(dir) if dir
end

describe Lune::Config do
  describe ".load" do
    it "returns a config with nil window fields when no lune.yml exists" do
      Dir.cd(Dir.tempdir) do
        config = Lune::Config.load("nonexistent_lune_#{Random.new.hex}.yml")
        config.window.title.should be_nil
        config.window.width.should be_nil
        config.window.height.should be_nil
        config.window.resizable.should be_nil
        config.window.devtools.should be_nil
      end
    end

    it "parses window.title" do
      with_lune_yml("window:\n  title: My App") do
        Lune::Config.load.window.title.should eq("My App")
      end
    end

    it "parses window.width and window.height" do
      with_lune_yml("window:\n  width: 1440\n  height: 900") do
        config = Lune::Config.load
        config.window.width.should eq(1440)
        config.window.height.should eq(900)
      end
    end

    it "parses window.min_width and window.min_height" do
      with_lune_yml("window:\n  min_width: 800\n  min_height: 600") do
        config = Lune::Config.load
        config.window.min_width.should eq(800)
        config.window.min_height.should eq(600)
      end
    end

    it "parses window.max_width and window.max_height" do
      with_lune_yml("window:\n  max_width: 1920\n  max_height: 1080") do
        config = Lune::Config.load
        config.window.max_width.should eq(1920)
        config.window.max_height.should eq(1080)
      end
    end

    it "parses window.resizable false" do
      with_lune_yml("window:\n  resizable: false") do
        Lune::Config.load.window.resizable.should be_false
      end
    end

    it "parses window.devtools true" do
      with_lune_yml("window:\n  devtools: true") do
        Lune::Config.load.window.devtools.should be_true
      end
    end

    it "returns nil window fields when lune.yml has no window section" do
      with_lune_yml("name: my_app") do
        config = Lune::Config.load
        config.window.title.should be_nil
        config.window.width.should be_nil
      end
    end

    it "returns default config on invalid YAML" do
      with_lune_yml(": bad: yaml: [") do
        config = Lune::Config.load
        config.window.title.should be_nil
      end
    end

    it "parses plugins enabled list" do
      with_lune_yml("plugins:\n  enabled:\n    - quit\n    - clipboardRead") do
        caps = Lune::Config.load.plugins
        caps.enabled.should eq(["quit", "clipboardRead"])
        caps.disabled.should be_nil
      end
    end

    it "parses plugins disabled list" do
      with_lune_yml("plugins:\n  disabled:\n    - environment") do
        caps = Lune::Config.load.plugins
        caps.enabled.should be_nil
        caps.disabled.should eq(["environment"])
      end
    end

    it "returns empty plugins when key is absent" do
      with_lune_yml("window:\n  title: My App") do
        caps = Lune::Config.load.plugins
        caps.enabled.should be_nil
        caps.disabled.should be_nil
      end
    end
  end
end

describe Lune::Options do
  describe "#apply" do
    it "leaves all defaults intact when window config is empty" do
      opts = Lune::Options.new
      opts.apply(Lune::Config::Window.new)
      opts.title.should eq("Lune")
      opts.width.should eq(1200)
      opts.height.should eq(800)
      opts.resizable.should be_true
      opts.devtools.should be_false
      opts.min_width.should be_nil
      opts.min_height.should be_nil
      opts.max_width.should be_nil
      opts.max_height.should be_nil
    end

    it "applies title" do
      opts = Lune::Options.new
      win = Lune::Config::Window.new
      win.title = "My App"
      opts.apply(win)
      opts.title.should eq("My App")
    end

    it "applies width and height" do
      opts = Lune::Options.new
      win = Lune::Config::Window.new
      win.width = 1440
      win.height = 900
      opts.apply(win)
      opts.width.should eq(1440)
      opts.height.should eq(900)
    end

    it "applies min/max dimensions" do
      opts = Lune::Options.new
      win = Lune::Config::Window.new
      win.min_width = 800
      win.min_height = 600
      win.max_width = 1920
      win.max_height = 1080
      opts.apply(win)
      opts.min_width.should eq(800)
      opts.min_height.should eq(600)
      opts.max_width.should eq(1920)
      opts.max_height.should eq(1080)
    end

    it "applies resizable false" do
      opts = Lune::Options.new
      win = Lune::Config::Window.new
      win.resizable = false
      opts.apply(win)
      opts.resizable.should be_false
    end

    it "applies devtools true" do
      opts = Lune::Options.new
      win = Lune::Config::Window.new
      win.devtools = true
      opts.apply(win)
      opts.devtools.should be_true
    end

    it "does not apply nil fields — existing value is preserved" do
      opts = Lune::Options.new
      opts.title = "Already Set"
      opts.apply(Lune::Config::Window.new)
      opts.title.should eq("Already Set")
    end
  end
end
