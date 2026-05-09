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

  def run(app_entry : String) : Bool
    @result
  end
end

private class LoggingBuildCommand < LuneCLI::BuildCommand
  def initialize(@result : Bool)
  end

  def run(frontend_dir : String, app_entry : String, output_path : String, release : Bool = false) : Bool
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

  def run(frontend_dir : String, app_entry : String, dev_url : String) : Bool
    @result
  end
end

class Argy::Command
  def __execute_without_rescue_for_spec(argv : Array(String)) : Nil
    argv = argv[1..] if argv.first? == name
    root = root_command
    root.reset_tree_state!
    root.validate_tree_flag_collisions!
    _execute(argv)
  end
end

describe "LuneCLI logging" do
  it "enables info logging by default before command preflight" do
    original = Lune.logger
    backend = CaptureBackend.new
    logger = Log.new("lune.spec.cli", backend, :none)

    begin
      Lune.logger = logger
      root = LuneCLI.root_command

      expect_raises(Argy::Error, /App entry file not found: missing_main\.cr/) do
        root.__execute_without_rescue_for_spec(["check", "--app-entry", "missing_main.cr"])
      end

      Lune.logger.level.should eq(Log::Severity::Info)

      entry = backend.entries.find { |e| e.message.includes?("App entry file not found: missing_main.cr") }
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
      root = LuneCLI.root_command

      expect_raises(Argy::Error, /App entry file not found: missing_main\.cr/) do
        root.__execute_without_rescue_for_spec(["check", "--app-entry", "missing_main.cr", "--debug"])
      end

      Lune.logger.level.should eq(Log::Severity::Debug)

      entry = backend.entries.find { |e| e.message.includes?("App entry file not found: missing_main.cr") }
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
      root = LuneCLI.root_command

      expect_raises(Argy::Error, /App entry file not found: missing_main\.cr/) do
        root.__execute_without_rescue_for_spec(["check", "--app-entry", "missing_main.cr"])
      end

      entry = backend.entries.find { |e| e.message.includes?("App entry file not found: missing_main.cr") }
      entry.should_not be_nil
      entry.not_nil!.severity.should eq(Log::Severity::Error)
    ensure
      Lune.logger = original
    end
  end

  it "logs build preflight failures" do
    original = Lune.logger
    backend = CaptureBackend.new
    logger = Log.new("lune.spec.cli", backend, :debug)

    begin
      Lune.logger = logger
      root = LuneCLI.root_command

      expect_raises(Argy::Error, /Frontend directory not found: missing_frontend/) do
        root.__execute_without_rescue_for_spec(["build", "--frontend-dir", "missing_frontend", "--app-entry", "spec/fixtures/main.cr"])
      end

      entry = backend.entries.find { |e| e.message.includes?("Frontend directory not found: missing_frontend") }
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

      command = LoggingCheckCommand.new(true).to_command
      command.flags.string("app-entry", nil, "spec/fixtures/main.cr", "app")
      command.__execute_without_rescue_for_spec([] of String)

      checking = backend.entries.find { |e| e.message.includes?("Checking spec/fixtures/main.cr...") }
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

      command = LoggingBuildCommand.new(false).to_command
      command.flags.string("frontend-dir", nil, "frontend", "frontend")
      command.flags.string("app-entry", nil, "spec/fixtures/main.cr", "app")

      expect_raises(Argy::Error, /build failed/) do
        command.__execute_without_rescue_for_spec([] of String)
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
      command.flags.string("app-entry", nil, "spec/fixtures/main.cr", "app")

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

    # Use a fixture name that will never have a matching build artifact on disk.
    fixture_entry = "spec/fixtures/never_built_app_#{Random.new.hex(6)}.cr"
    File.write(fixture_entry, "# placeholder\n")

    begin
      Lune.logger = logger
      root = LuneCLI.root_command

      missing_artifact = {% if flag?(:darwin) %}
                           "build/bin/never_built_app_"
                         {% else %}
                           "build/bin/never_built_app_"
                         {% end %}

      expect_raises(Argy::Error, /Built app not found/) do
        root.__execute_without_rescue_for_spec(["run", "--app-entry", fixture_entry])
      end

      entry = backend.entries.find { |e| e.message.includes?("Built app not found") }
      entry.should_not be_nil
      entry.not_nil!.severity.should eq(Log::Severity::Error)
    ensure
      File.delete(fixture_entry) rescue nil
      Lune.logger = original
    end
  end

  it "logs dev failure before raising" do
    original = Lune.logger
    backend = CaptureBackend.new
    logger = Log.new("lune.spec.cli", backend, :debug)

    begin
      Lune.logger = logger

      command = LoggingDevCommand.new(false).to_command
      command.flags.string("frontend-dir", nil, "frontend", "frontend")
      command.flags.string("app-entry", nil, "spec/fixtures/main.cr", "app")

      expect_raises(Argy::Error, /dev failed/) do
        command.__execute_without_rescue_for_spec([] of String)
      end

      entry = backend.entries.find { |e| e.message == "dev failed" }
      entry.should_not be_nil
      entry.not_nil!.severity.should eq(Log::Severity::Error)
    ensure
      Lune.logger = original
    end
  end
end
