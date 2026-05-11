require "spec"
require "file_utils"
require "../src/lune_cli"

private def with_tempdir(& : String -> _)
  dir = File.join(Dir.tempdir, "lune_cli_#{Random.new.hex(8)}")
  Dir.mkdir_p(dir)
  begin
    yield dir
  ensure
    FileUtils.rm_rf(dir)
  end
end

describe LuneCLI do
  describe ".root_command" do
    it "builds a root argy command named lune" do
      cmd = LuneCLI.root_command

      cmd.name.should eq("lune")
      cmd.subcommands.has_key?("check").should be_true
      cmd.subcommands.has_key?("dev").should be_true
      cmd.subcommands.has_key?("build").should be_true
      cmd.subcommands.has_key?("run").should be_true
      cmd.subcommands.has_key?("version").should be_true
      cmd.subcommands.has_key?("doctor").should be_true
    end

    it "registers short aliases for dev, build, and run" do
      cmd = LuneCLI.root_command

      cmd.subcommands.has_key?("d").should be_true
      cmd.subcommands.has_key?("b").should be_true
      cmd.subcommands.has_key?("r").should be_true
    end

    it "exposes only --debug as a persistent flag (frontend-dir and app-entry belong in lune.yml)" do
      cmd = LuneCLI.root_command

      cmd.persistent_flags.lookup("debug").should_not be_nil
      cmd.persistent_flags.lookup("frontend-dir").should be_nil
      cmd.persistent_flags.lookup("app-entry").should be_nil
      cmd.bool_flag("debug").should be_false
    end

    it "renders help that mentions the check command" do
      cmd = LuneCLI.root_command
      io = IO::Memory.new

      cmd.print_help(io)
      output = io.to_s

      output.includes?("Usage:").should be_true
      output.includes?("check").should be_true
    end
  end

  describe "dev command" do
    it "returns nil when both paths exist" do
      cmd = LuneCLI::DevCommand.new
      cmd.validate_paths(frontend_dir: "frontend", app_entry: "spec/fixtures/main.cr").should be_nil
    end

    it "rejects a missing app entry" do
      cmd = LuneCLI::DevCommand.new
      cmd.validate_paths(frontend_dir: "frontend", app_entry: "missing_main.cr")
        .should eq("App entry file not found: missing_main.cr")
    end

    it "rejects a missing frontend dir" do
      cmd = LuneCLI::DevCommand.new
      cmd.validate_paths(frontend_dir: "missing_frontend", app_entry: "spec/fixtures/main.cr")
        .should eq("Frontend directory not found: missing_frontend")
    end

    it "dev_lock_slug is prefixed with dev- and derived from the app entry path" do
      cmd = LuneCLI::DevCommand.new
      slug = cmd.dev_lock_slug("src/main.cr")
      slug.should start_with("dev-")
      slug.size.should be > "dev-".size
    end

    it "does not expose a --dev-cmd flag (belongs in lune.yml)" do
      cmd = LuneCLI::DevCommand.new.to_command
      cmd.flags.lookup("dev-cmd").should be_nil
    end

    it "returns false immediately when a dev lock is already held for the same entry" do
      with_tempdir do |lock_dir|
        cmd = LuneCLI::DevCommand.new
        slug = cmd.dev_lock_slug("spec/fixtures/main.cr")
        held = Lune::SingleInstance.acquire(slug, lock_dir)
        held.should_not be_nil

        result = cmd.run(
          frontend_dir: "frontend",
          app_entry: "spec/fixtures/main.cr",
          dev_url: "http://localhost:5173",
          lock_dir: lock_dir
        )
        result.should be_false

        held.try(&.close)
      end
    end
  end

  describe "build command" do
    it "derives the default output path from the app entry" do
      cmd = LuneCLI::BuildCommand.new

      expected_output = {% if flag?(:darwin) %}
                          "build/bin/main.app"
                        {% else %}
                          "build/bin/main"
                        {% end %}

      cmd.output_path_for("main.cr").should eq(expected_output)
    end

    it "rejects a missing frontend dir" do
      cmd = LuneCLI::BuildCommand.new
      cmd.validate_paths(frontend_dir: "missing_frontend", app_entry: "spec/fixtures/main.cr")
        .should eq("Frontend directory not found: missing_frontend")
    end

    it "rejects a missing app entry" do
      cmd = LuneCLI::BuildCommand.new
      cmd.validate_paths(frontend_dir: "frontend", app_entry: "missing_main.cr")
        .should eq("App entry file not found: missing_main.cr")
    end

    it "registers a --release flag" do
      cmd = LuneCLI::BuildCommand.new.to_command
      cmd.flags.lookup("release").should_not be_nil
    end

    it "does not expose a --build-cmd flag (belongs in lune.yml)" do
      cmd = LuneCLI::BuildCommand.new.to_command
      cmd.flags.lookup("build-cmd").should be_nil
    end
  end

  describe "version command" do
    it "is registered on the root command" do
      cmd = LuneCLI.root_command
      cmd.subcommands.has_key?("version").should be_true
    end

    it "version string includes the lune version constant" do
      LuneCLI::VersionCommand.new.version_string.should eq("lune v#{Lune::VERSION}")
    end
  end

  describe LuneCLI::Config do
    describe ".load" do
      it "returns a default config when the file does not exist" do
        config = LuneCLI::Config.load("nonexistent_lune.yml")
        config.dev_cmd.should be_nil
        config.build_cmd.should be_nil
        config.dev_url.should be_nil
        config.app_entry.should eq("src/main.cr")
        config.frontend_dir.should eq("frontend")
      end

      it "loads values from a YAML file" do
        with_tempdir do |dir|
          path = File.join(dir, "lune.yml")
          File.write(path, "dev_cmd: mint start\nbuild_cmd: mint build\ndev_url: http://localhost:3000\n")
          config = LuneCLI::Config.load(path)
          config.dev_cmd.should eq("mint start")
          config.build_cmd.should eq("mint build")
          config.dev_url.should eq("http://localhost:3000")
        end
      end

      it "accepts a partial config with only some keys" do
        with_tempdir do |dir|
          path = File.join(dir, "lune.yml")
          File.write(path, "name: myapp\n")
          config = LuneCLI::Config.load(path)
          config.name.should eq("myapp")
          config.dev_cmd.should be_nil
        end
      end

      it "returns an all-nil config when the file is invalid YAML" do
        with_tempdir do |dir|
          path = File.join(dir, "lune.yml")
          File.write(path, ":\nbroken: [yaml")
          config = LuneCLI::Config.load(path)
          config.dev_cmd.should be_nil
        end
      end
    end
  end

  describe "NPM_CMD" do
    it "is npm on non-Windows platforms" do
      {% unless flag?(:win32) %}
        LuneCLI::NPM_CMD.should eq("npm")
      {% end %}
    end

    it "is npm.cmd on Windows" do
      {% if flag?(:win32) %}
        LuneCLI::NPM_CMD.should eq("npm.cmd")
      {% end %}
    end
  end

  describe "init command" do
    it "always includes install in shards_install_args" do
      LuneCLI::InitCommand.new.shards_install_args.should contain("install")
    end

    it "adds --skip-postinstall only on Windows" do
      cmd = LuneCLI::InitCommand.new
      {% if flag?(:win32) %}
        cmd.shards_install_args.should contain("--skip-postinstall")
      {% else %}
        cmd.shards_install_args.should_not contain("--skip-postinstall")
      {% end %}
    end

    it "injects the current major.minor lune version into shard.yml" do
      with_tempdir do |dir|
        shard_yml = File.join(dir, "shard.yml")
        File.write(shard_yml, "name: testapp\nversion: 0.1.0\n")

        LuneCLI::InitCommand.new.inject_dependency(shard_yml)

        content = File.read(shard_yml)
        expected = "~> #{Lune::VERSION.split(".").first(2).join(".")}"
        content.should contain(expected)
      end
    end
  end

  describe "run command" do
    it "derives the built artifact path from the app entry" do
      cmd = LuneCLI::RunCommand.new

      expected_output = {% if flag?(:darwin) %}
                          "build/bin/main.app"
                        {% else %}
                          "build/bin/main"
                        {% end %}

      cmd.artifact_path_for("main.cr").should eq(expected_output)
    end

    it "returns false immediately when a run lock is already held for the same entry" do
      with_tempdir do |lock_dir|
        cmd = LuneCLI::RunCommand.new
        slug = cmd.run_lock_slug("src/main.cr")
        held = Lune::SingleInstance.acquire(slug, lock_dir)
        held.should_not be_nil

        result = cmd.run(app_entry: "src/main.cr", lock_dir: lock_dir)
        result.should be_false

        held.try(&.close)
      end
    end

    it "run_lock_slug differs from dev_lock_slug for the same entry" do
      run_cmd = LuneCLI::RunCommand.new
      dev_cmd = LuneCLI::DevCommand.new
      run_cmd.run_lock_slug("src/main.cr").should_not eq(dev_cmd.dev_lock_slug("src/main.cr"))
    end
  end

  describe ".pregen_runtime_js" do
    it "writes app and runtime JS into frontend_dir/lunejs/" do
      with_tempdir do |tmpdir|
        LuneCLI.pregen_runtime_js(tmpdir)
        File.exists?(File.join(tmpdir, "lunejs", "app", "App.js")).should be_true
        File.exists?(File.join(tmpdir, "lunejs", "runtime", "runtime.js")).should be_true
      end
    end

    it "creates the lunejs dir if it does not exist yet" do
      with_tempdir do |tmpdir|
        new_dir = File.join(tmpdir, "brand_new_frontend")
        LuneCLI.pregen_runtime_js(new_dir)
        File.exists?(File.join(new_dir, "lunejs", "app", "App.js")).should be_true
      end
    end
  end
end
