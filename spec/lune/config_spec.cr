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
    it "returns default plugins when no lune.yml exists" do
      config = Lune::Config.load("nonexistent_lune_#{Random.new.hex}.yml")
      config.plugins.enabled.should be_nil
      config.plugins.disabled.should be_nil
    end

    it "returns default config on invalid YAML" do
      with_lune_yml(": bad: yaml: [") do
        config = Lune::Config.load
        config.plugins.enabled.should be_nil
        config.plugins.disabled.should be_nil
      end
    end

    it "parses plugins enabled list" do
      with_lune_yml("plugins:\n  enabled:\n    - quit\n    - clipboardRead") do
        plugins = Lune::Config.load.plugins
        plugins.enabled.should eq(["quit", "clipboardRead"])
        plugins.disabled.should be_nil
      end
    end

    it "parses plugins disabled list" do
      with_lune_yml("plugins:\n  disabled:\n    - environment") do
        plugins = Lune::Config.load.plugins
        plugins.enabled.should be_nil
        plugins.disabled.should eq(["environment"])
      end
    end

    it "returns empty plugins when key is absent" do
      with_lune_yml("name: My App") do
        plugins = Lune::Config.load.plugins
        plugins.enabled.should be_nil
        plugins.disabled.should be_nil
      end
    end
  end
end
