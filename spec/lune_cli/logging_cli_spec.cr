require "../spec_helper"

private class LoggingCheckCommand < LuneCLI::Commands::Check
  def initialize(@result : Bool)
  end

  def validate_paths(app_entry : String) : String?
    nil
  end

  def run(app_entry : String) : Bool
    @result
  end
end

private class LoggingBuildCommand < LuneCLI::Commands::Build
  def initialize(@result : Bool)
  end

  def validate_paths(frontend_dir : String, app_entry : String) : String?
    nil
  end

  def run(frontend_dir : String, app_entry : String, output_path : String, release : Bool = false, build_cmd : String = LuneCLI::DEFAULT_BUILD_CMD) : Bool
    @result
  end
end

private class LoggingRunCommand < LuneCLI::Commands::Run
  def initialize(@result : Bool)
  end

  def validate_paths(app_entry : String) : String?
    nil
  end

  def run(app_entry : String) : Bool
    @result
  end
end

private class LoggingDevCommand < LuneCLI::Commands::Dev
  def initialize(@result : Bool)
  end

  def validate_paths(frontend_dir : String, app_entry : String) : String?
    nil
  end

  def run(frontend_dir : String, app_entry : String, dev_url : String, dev_cmd : String = LuneCLI::DEFAULT_DEV_CMD, watcher : LuneCLI::FileWatcher = LuneCLI::FileWatcher.new, lock_dir : String = File.join(Path.home, ".lune")) : Bool
    @result
  end
end

describe "LuneCLI logging" do
  # In a blank temp dir: default app_entry is "src/main.cr" which does not exist.
  it "enables info logging by default before command preflight" do
    backend = CaptureBackend.new
    logger = Log.new("lune.spec.cli", backend, :none)

    with_logger(logger) do
      in_blank_project do
        root = LuneCLI.root_command

        expect_raises(Argy::Error, /App entry file not found: src\/main\.cr/) do
          root.__execute_without_rescue_for_spec(["check"])
        end
      end

      logger.level.should eq(Log::Severity::Info)
    end
  end

  it "enables debug logging from the global flag before command preflight" do
    backend = CaptureBackend.new
    logger = Log.new("lune.spec.cli", backend, :none)

    with_logger(logger) do
      in_blank_project do
        root = LuneCLI.root_command

        expect_raises(Argy::Error, /App entry file not found: src\/main\.cr/) do
          root.__execute_without_rescue_for_spec(["check", "--debug"])
        end
      end

      logger.level.should eq(Log::Severity::Debug)
    end
  end

  it "logs check progress and success" do
    backend = CaptureBackend.new
    logger = Log.new("lune.spec.cli", backend, :debug)

    with_logger(logger) do
      in_project_with("app_entry: my_app.cr\n") do
        command = LoggingCheckCommand.new(true).to_command
        command.__execute_without_rescue_for_spec([] of String)
      end
    end

    checking = backend.entries.find { |e| e.message == "Checking my_app.cr..." }
    checking.should_not be_nil
    checking.not_nil!.severity.should eq(Log::Severity::Info)

    ok = backend.entries.find { |e| e.message == "OK" }
    ok.should_not be_nil
    ok.not_nil!.severity.should eq(Log::Severity::Info)
  end

  it "raises on missing app entry during check preflight" do
    in_blank_project do
      root = LuneCLI.root_command

      expect_raises(Argy::Error, /App entry file not found: src\/main\.cr/) do
        root.__execute_without_rescue_for_spec(["check"])
      end
    end
  end

  it "raises on missing frontend dir during build preflight" do
    in_blank_project do
      root = LuneCLI.root_command

      expect_raises(Argy::Error, /Frontend directory not found: frontend/) do
        root.__execute_without_rescue_for_spec(["build"])
      end
    end
  end

  it "raises on build failure" do
    in_blank_project do
      command = LoggingBuildCommand.new(false).to_command

      expect_raises(Argy::Error, /build failed/) do
        command.__execute_without_rescue_for_spec([] of String)
      end
    end
  end

  it "raises on run failure" do
    command = LoggingRunCommand.new(false).to_command

    expect_raises(Argy::Error, /run failed/) do
      command.__execute_without_rescue_for_spec([] of String)
    end
  end

  it "raises on missing built artifact" do
    dir = File.join(Dir.tempdir, "lune_log_artifacts_#{Random.new.hex(6)}")
    Dir.mkdir_p(dir)
    File.write(File.join(dir, "my_app.cr"), "# placeholder\n")
    File.write(File.join(dir, "lune.yml"), "app_entry: my_app.cr\n")

    begin
      Dir.cd(dir) do
        root = LuneCLI.root_command

        expect_raises(Argy::Error, /Built app not found/) do
          root.__execute_without_rescue_for_spec(["run"])
        end
      end
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  it "raises on dev failure" do
    in_blank_project do
      command = LoggingDevCommand.new(false).to_command

      expect_raises(Argy::Error, /dev failed/) do
        command.__execute_without_rescue_for_spec([] of String)
      end
    end
  end
end
