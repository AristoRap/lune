require "./spec_helper"
require "../src/lune_cli"

private class CaptureBackend < Log::Backend
  getter entries = [] of Log::Entry

  def initialize
    super(:sync)
  end

  def write(entry : Log::Entry)
    @entries << entry
  end
end

private class LoggingCheckCommand < LuneCLI::CheckCommand
  def initialize(@result : Bool)
  end

  def validate_paths(app_entry : String) : String?
    nil
  end

  def run(app_entry : String) : Bool
    @result
  end
end

private class LoggingBuildCommand < LuneCLI::BuildCommand
  def initialize(@result : Bool)
  end

  def validate_paths(frontend_dir : String, app_entry : String) : String?
    nil
  end

  def run(frontend_dir : String, app_entry : String, output_path : String, release : Bool = false, build_cmd : String = LuneCLI::BuildCommand::DEFAULT_BUILD_CMD) : Bool
    @result
  end
end

private class LoggingRunCommand < LuneCLI::RunCommand
  def initialize(@result : Bool)
  end

  def validate_paths(app_entry : String) : String?
    nil
  end

  def run(app_entry : String) : Bool
    @result
  end
end

private class LoggingDevCommand < LuneCLI::DevCommand
  def initialize(@result : Bool)
  end

  def validate_paths(frontend_dir : String, app_entry : String) : String?
    nil
  end

  def run(frontend_dir : String, app_entry : String, dev_url : String, dev_cmd : String = LuneCLI::DevCommand::DEFAULT_DEV_CMD, watcher : LuneCLI::FileWatcher = LuneCLI::FileWatcher.new, lock_dir : String = File.join(Path.home, ".lune")) : Bool
    @result
  end
end


# Runs the block inside a temp dir that has no lune.yml, so Config defaults apply.
private def in_blank_project(& : ->)
  dir = File.join(Dir.tempdir, "lune_log_#{Random.new.hex(6)}")
  Dir.mkdir_p(dir)
  begin
    Dir.cd(dir) { yield }
  ensure
    FileUtils.rm_rf(dir)
  end
end

# Runs the block inside a temp dir with the given lune.yml content.
private def in_project_with(lune_yml : String, & : ->)
  dir = File.join(Dir.tempdir, "lune_log_#{Random.new.hex(6)}")
  Dir.mkdir_p(dir)
  File.write(File.join(dir, "lune.yml"), lune_yml)
  begin
    Dir.cd(dir) { yield }
  ensure
    FileUtils.rm_rf(dir)
  end
end

describe "LuneCLI logging" do
  # In a blank temp dir: default app_entry is "src/main.cr" which does not exist.
  it "enables info logging by default before command preflight" do
    original = Lune.logger
    backend = CaptureBackend.new
    logger = Log.new("lune.spec.cli", backend, :none)

    begin
      Lune.logger = logger

      in_blank_project do
        root = LuneCLI.root_command

        expect_raises(Argy::Error, /App entry file not found: src\/main\.cr/) do
          root.__execute_without_rescue_for_spec(["check"])
        end
      end

      Lune.logger.level.should eq(Log::Severity::Info)

      entry = backend.entries.find { |e| e.message.includes?("App entry file not found: src/main.cr") }
      entry.should_not be_nil
      entry.not_nil!.severity.should eq(Log::Severity::Error)
    ensure
      Lune.logger = original
    end
  end

  it "enables debug logging from the global flag before command preflight" do
    original = Lune.logger
    backend = CaptureBackend.new
    logger = Log.new("lune.spec.cli", backend, :none)

    begin
      Lune.logger = logger

      in_blank_project do
        root = LuneCLI.root_command

        expect_raises(Argy::Error, /App entry file not found: src\/main\.cr/) do
          root.__execute_without_rescue_for_spec(["check", "--debug"])
        end
      end

      Lune.logger.level.should eq(Log::Severity::Debug)

      entry = backend.entries.find { |e| e.message.includes?("App entry file not found: src/main.cr") }
      entry.should_not be_nil
      entry.not_nil!.severity.should eq(Log::Severity::Error)
    ensure
      Lune.logger = original
    end
  end

  it "logs check preflight failures" do
    original = Lune.logger
    backend = CaptureBackend.new
    logger = Log.new("lune.spec.cli", backend, :debug)

    begin
      Lune.logger = logger

      in_blank_project do
        root = LuneCLI.root_command

        expect_raises(Argy::Error, /App entry file not found: src\/main\.cr/) do
          root.__execute_without_rescue_for_spec(["check"])
        end
      end

      entry = backend.entries.find { |e| e.message.includes?("App entry file not found: src/main.cr") }
      entry.should_not be_nil
      entry.not_nil!.severity.should eq(Log::Severity::Error)
    ensure
      Lune.logger = original
    end
  end

  # In a blank temp dir: default frontend_dir is "frontend" which does not exist there.
  it "logs build preflight failures" do
    original = Lune.logger
    backend = CaptureBackend.new
    logger = Log.new("lune.spec.cli", backend, :debug)

    begin
      Lune.logger = logger

      in_blank_project do
        root = LuneCLI.root_command

        expect_raises(Argy::Error, /Frontend directory not found: frontend/) do
          root.__execute_without_rescue_for_spec(["build"])
        end
      end

      entry = backend.entries.find { |e| e.message.includes?("Frontend directory not found: frontend") }
      entry.should_not be_nil
      entry.not_nil!.severity.should eq(Log::Severity::Error)
    ensure
      Lune.logger = original
    end
  end

  it "logs check progress and success" do
    original = Lune.logger
    backend = CaptureBackend.new
    logger = Log.new("lune.spec.cli", backend, :debug)

    begin
      Lune.logger = logger

      in_project_with("app_entry: my_app.cr\n") do
        command = LoggingCheckCommand.new(true).to_command
        command.__execute_without_rescue_for_spec([] of String)
      end

      checking = backend.entries.find { |e| e.message == "Checking my_app.cr..." }
      checking.should_not be_nil
      checking.not_nil!.severity.should eq(Log::Severity::Info)

      ok = backend.entries.find { |e| e.message == "OK" }
      ok.should_not be_nil
      ok.not_nil!.severity.should eq(Log::Severity::Info)
    ensure
      Lune.logger = original
    end
  end

  it "logs build failure before raising" do
    original = Lune.logger
    backend = CaptureBackend.new
    logger = Log.new("lune.spec.cli", backend, :debug)

    begin
      Lune.logger = logger

      in_blank_project do
        command = LoggingBuildCommand.new(false).to_command

        expect_raises(Argy::Error, /build failed/) do
          command.__execute_without_rescue_for_spec([] of String)
        end
      end

      entry = backend.entries.find { |e| e.message == "build failed" }
      entry.should_not be_nil
      entry.not_nil!.severity.should eq(Log::Severity::Error)
    ensure
      Lune.logger = original
    end
  end

  it "logs run failure before raising" do
    original = Lune.logger
    backend = CaptureBackend.new
    logger = Log.new("lune.spec.cli", backend, :debug)

    begin
      Lune.logger = logger

      command = LoggingRunCommand.new(false).to_command

      expect_raises(Argy::Error, /run failed/) do
        command.__execute_without_rescue_for_spec([] of String)
      end

      entry = backend.entries.find { |e| e.message == "run failed" }
      entry.should_not be_nil
      entry.not_nil!.severity.should eq(Log::Severity::Error)
    ensure
      Lune.logger = original
    end
  end

  it "logs missing built artifacts before raising" do
    original = Lune.logger
    backend = CaptureBackend.new
    logger = Log.new("lune.spec.cli", backend, :debug)

    dir = File.join(Dir.tempdir, "lune_log_artifacts_#{Random.new.hex(6)}")
    Dir.mkdir_p(dir)
    File.write(File.join(dir, "my_app.cr"), "# placeholder\n")
    File.write(File.join(dir, "lune.yml"), "app_entry: my_app.cr\n")

    begin
      Lune.logger = logger

      Dir.cd(dir) do
        root = LuneCLI.root_command

        expect_raises(Argy::Error, /Built app not found/) do
          root.__execute_without_rescue_for_spec(["run"])
        end
      end

      entry = backend.entries.find { |e| e.message.includes?("Built app not found") }
      entry.should_not be_nil
      entry.not_nil!.severity.should eq(Log::Severity::Error)
    ensure
      FileUtils.rm_rf(dir)
      Lune.logger = original
    end
  end

  it "logs dev failure before raising" do
    original = Lune.logger
    backend = CaptureBackend.new
    logger = Log.new("lune.spec.cli", backend, :debug)

    begin
      Lune.logger = logger

      in_blank_project do
        command = LoggingDevCommand.new(false).to_command

        expect_raises(Argy::Error, /dev failed/) do
          command.__execute_without_rescue_for_spec([] of String)
        end
      end

      entry = backend.entries.find { |e| e.message == "dev failed" }
      entry.should_not be_nil
      entry.not_nil!.severity.should eq(Log::Severity::Error)
    ensure
      Lune.logger = original
    end
  end
end
