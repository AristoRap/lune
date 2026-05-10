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
    end

    it "defines shared frontend and app flags on the root command" do
      cmd = LuneCLI.root_command

      cmd.persistent_flags.lookup("debug").should_not be_nil
      cmd.persistent_flags.lookup("frontend-dir").should_not be_nil
      cmd.persistent_flags.lookup("app-entry").should_not be_nil
      cmd.bool_flag("debug").should be_false
      cmd.string_flag("frontend-dir").should eq("frontend")
      cmd.string_flag("app-entry").should eq("src/main.cr")
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
