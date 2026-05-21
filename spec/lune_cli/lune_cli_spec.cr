require "spec"
require "file_utils"
require "../spec_helper"

private class ExposedBuildCommand < LuneCLI::Commands::Build
  def call_png_to_icns(path : String) : String?
    png_to_icns(path)
  end

  def call_info_plist_for(app_entry : String, icon_name : String? = nil, display_name : String? = nil, bundle_id : String? = nil, url_schemes : Array(String) = [] of String) : String
    info_plist_for(app_entry, icon_name, display_name, bundle_id, url_schemes)
  end

  {% if flag?(:darwin) %}
    def call_write_default_entitlements : String
      write_default_entitlements
    end
  {% end %}
end

private class ExposedDistCommand < LuneCLI::Commands::Dist
  {% if flag?(:linux) %}
    def call_desktop_entry_for(app_name : String, url_schemes : Array(String) = [] of String) : String
      desktop_entry_for(app_name, url_schemes)
    end
  {% end %}
end

private class RecordingDoctorCommand < LuneCLI::Commands::Doctor
  getter captured_frontend_dir : String = ""
  getter captured_app_entry : String = ""

  def run(frontend_dir : String, app_entry : String, install_hint : String = LuneCLI::DEFAULT_INSTALL_CMD, output : IO = STDOUT) : Bool
    @captured_frontend_dir = frontend_dir
    @captured_app_entry = app_entry
    true
  end
end

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
      cmd.subcommands.has_key?("dist").should be_true
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
      cmd = LuneCLI::Commands::Dev.new
      cmd.validate_paths(frontend_dir: "spec", app_entry: "spec/fixtures/main.cr").should be_nil
    end

    it "rejects a missing app entry" do
      cmd = LuneCLI::Commands::Dev.new
      cmd.validate_paths(frontend_dir: "spec", app_entry: "missing_main.cr")
        .should eq("App entry file not found: missing_main.cr")
    end

    it "rejects a missing frontend dir" do
      cmd = LuneCLI::Commands::Dev.new
      cmd.validate_paths(frontend_dir: "missing_frontend", app_entry: "spec/fixtures/main.cr")
        .should eq("Frontend directory not found: missing_frontend")
    end

    it "dev_lock_slug is prefixed with dev- and derived from the app entry path" do
      cmd = LuneCLI::Commands::Dev.new
      slug = cmd.dev_lock_slug("src/main.cr")
      slug.should start_with("dev-")
      slug.size.should be > "dev-".size
    end

    it "does not expose a --dev-cmd flag (belongs in lune.yml)" do
      cmd = LuneCLI::Commands::Dev.new.to_command
      cmd.flags.lookup("dev-cmd").should be_nil
    end

    it "returns false immediately when a dev lock is already held for the same entry" do
      with_tempdir do |lock_dir|
        cmd = LuneCLI::Commands::Dev.new
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
    it "derives the default output path from the app entry when no name is set" do
      cmd = LuneCLI::Commands::Build.new

      expected_output = {% if flag?(:darwin) %}
                          "build/bin/main.app"
                        {% elsif flag?(:win32) %}
                          "build\\bin\\main.exe"
                        {% else %}
                          "build/bin/main"
                        {% end %}

      cmd.output_path_for("main.cr").should eq(expected_output)
    end

    it "uses config name as the bundle name when set" do
      cmd = LuneCLI::Commands::Build.new

      expected_output = {% if flag?(:darwin) %}
                          "build/bin/demo.app"
                        {% elsif flag?(:win32) %}
                          "build\\bin\\demo.exe"
                        {% else %}
                          "build/bin/demo"
                        {% end %}

      cmd.output_path_for("src/main.cr", "demo").should eq(expected_output)
    end

    it "bundle_name_for returns name when set, entry basename otherwise" do
      cmd = LuneCLI::Commands::Build.new
      cmd.bundle_name_for("src/main.cr", "demo").should eq("demo")
      cmd.bundle_name_for("src/main.cr", nil).should eq("main")
    end

    it "rejects a missing frontend dir" do
      cmd = LuneCLI::Commands::Build.new
      cmd.validate_paths(frontend_dir: "missing_frontend", app_entry: "spec/fixtures/main.cr")
        .should eq("Frontend directory not found: missing_frontend")
    end

    it "rejects a missing app entry" do
      cmd = LuneCLI::Commands::Build.new
      cmd.validate_paths(frontend_dir: "spec", app_entry: "missing_main.cr")
        .should eq("App entry file not found: missing_main.cr")
    end

    it "registers a --release flag" do
      cmd = LuneCLI::Commands::Build.new.to_command
      cmd.flags.lookup("release").should_not be_nil
    end

    it "does not expose a --build-cmd flag (belongs in lune.yml)" do
      cmd = LuneCLI::Commands::Build.new.to_command
      cmd.flags.lookup("build-cmd").should be_nil
    end

    {% if flag?(:darwin) %}
      it "png_to_icns converts a PNG to a .icns file" do
        cmd = ExposedBuildCommand.new
        result = cmd.call_png_to_icns("spec/fixtures/icon.png")
        result.should_not be_nil
        File.exists?(result.not_nil!).should be_true
        File.extname(result.not_nil!).should eq(".icns")
      end
    {% end %}
  end

  describe "version command" do
    it "is registered on the root command" do
      cmd = LuneCLI.root_command
      cmd.subcommands.has_key?("version").should be_true
    end

    it "version string includes the lune version constant" do
      LuneCLI::Commands::Version.new.version_string.should eq("lune v#{Lune::VERSION}")
    end
  end

  describe LuneCLI::Config do
    describe ".load" do
      it "returns defaults when the file does not exist" do
        config = LuneCLI::Config.load("nonexistent_lune.yml")
        config.app_entry.should eq("src/main.cr")
        config.frontend.dir.should eq("frontend")
        config.frontend.install.should be_nil
        config.frontend.build.should be_nil
        config.frontend.dev.cmd.should be_nil
        config.frontend.dev.url.should eq("http://localhost:5173")
      end

      it "loads nested frontend values from a YAML file" do
        with_tempdir do |dir|
          path = File.join(dir, "lune.yml")
          File.write(path, <<-YAML)
            frontend:
              dir: my_frontend
              install: pnpm install
              build: pnpm run build
              dev:
                cmd: pnpm run dev
                url: http://localhost:3000
            YAML
          config = LuneCLI::Config.load(path)
          config.frontend.dir.should eq("my_frontend")
          config.frontend.install.should eq("pnpm install")
          config.frontend.build.should eq("pnpm run build")
          config.frontend.dev.cmd.should eq("pnpm run dev")
          config.frontend.dev.url.should eq("http://localhost:3000")
        end
      end

      it "accepts a partial config — absent frontend keys use defaults" do
        with_tempdir do |dir|
          path = File.join(dir, "lune.yml")
          File.write(path, "name: myapp\n")
          config = LuneCLI::Config.load(path)
          config.name.should eq("myapp")
          config.frontend.dev.cmd.should be_nil
          config.frontend.dev.url.should eq("http://localhost:5173")
        end
      end

      it "loads icon from lune.yml" do
        with_tempdir do |dir|
          path = File.join(dir, "lune.yml")
          File.write(path, "icon: assets/icon.icns\n")
          LuneCLI::Config.load(path).icon.should eq("assets/icon.icns")
        end
      end

      it "icon defaults to nil when not set" do
        LuneCLI::Config.load("nonexistent_lune.yml").icon.should be_nil
      end

      it "reads mac.sign from lune.yml" do
        with_tempdir do |dir|
          path = File.join(dir, "lune.yml")
          File.write(path, "mac:\n  sign: \"Developer ID Application: Foo (ABC123)\"\n")
          LuneCLI::Config.load(path).mac.sign.should eq("Developer ID Application: Foo (ABC123)")
        end
      end

      it "mac.sign defaults to nil when not set" do
        LuneCLI::Config.load("nonexistent_lune.yml").mac.sign.should be_nil
      end

      it "reads mac.notarize from lune.yml" do
        with_tempdir do |dir|
          path = File.join(dir, "lune.yml")
          File.write(path, "mac:\n  notarize: true\n")
          LuneCLI::Config.load(path).mac.notarize.should be_true
        end
      end

      it "mac.notarize defaults to false when not set" do
        LuneCLI::Config.load("nonexistent_lune.yml").mac.notarize.should be_false
      end

      it "reads mac.entitlements from lune.yml" do
        with_tempdir do |dir|
          path = File.join(dir, "lune.yml")
          File.write(path, "mac:\n  entitlements: assets/entitlements.plist\n")
          LuneCLI::Config.load(path).mac.entitlements.should eq("assets/entitlements.plist")
        end
      end

      it "mac.entitlements defaults to nil when not set" do
        LuneCLI::Config.load("nonexistent_lune.yml").mac.entitlements.should be_nil
      end

      it "reads mac.bundle_id from lune.yml" do
        with_tempdir do |dir|
          path = File.join(dir, "lune.yml")
          File.write(path, "mac:\n  bundle_id: com.example.myapp\n")
          LuneCLI::Config.load(path).mac.bundle_id.should eq("com.example.myapp")
        end
      end

      it "mac.bundle_id defaults to nil when not set" do
        LuneCLI::Config.load("nonexistent_lune.yml").mac.bundle_id.should be_nil
      end

      it "reads url_schemes from lune.yml" do
        with_tempdir do |dir|
          path = File.join(dir, "lune.yml")
          File.write(path, "url_schemes:\n  - myapp\n  - myapp-alt\n")
          LuneCLI::Config.load(path).url_schemes.should eq(["myapp", "myapp-alt"])
        end
      end

      it "url_schemes defaults to empty array when not set" do
        LuneCLI::Config.load("nonexistent_lune.yml").url_schemes.should be_empty
      end

      it "returns defaults when the file is invalid YAML" do
        with_tempdir do |dir|
          path = File.join(dir, "lune.yml")
          File.write(path, ":\nbroken: [yaml")
          config = LuneCLI::Config.load(path)
          config.frontend.dev.cmd.should be_nil
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
      LuneCLI::Commands::Init.new.shards_install_args.should contain("install")
    end

    it "adds --skip-postinstall only on Windows" do
      cmd = LuneCLI::Commands::Init.new
      {% if flag?(:win32) %}
        cmd.shards_install_args.should contain("--skip-postinstall")
      {% else %}
        cmd.shards_install_args.should_not contain("--skip-postinstall")
      {% end %}
    end

    it "registers --force and --skip-existing flags" do
      cmd = LuneCLI::Commands::Init.new.to_command
      cmd.flags.lookup("force").should_not be_nil
      cmd.flags.lookup("skip-existing").should_not be_nil
    end

    it "injects the current major.minor lune version into shard.yml" do
      with_tempdir do |dir|
        shard_yml = File.join(dir, "shard.yml")
        File.write(shard_yml, "name: testapp\nversion: 0.1.0\n")

        LuneCLI::Commands::Init.new.inject_dependency(shard_yml)

        content = File.read(shard_yml)
        expected = "~> #{Lune::VERSION.split(".").first(2).join(".")}"
        content.should contain(expected)
      end
    end
  end

  describe "dist command" do
    it "is registered on the root command" do
      LuneCLI.root_command.subcommands.has_key?("dist").should be_true
    end

    it "registers a --skip-notarize flag" do
      cmd = LuneCLI::Commands::Dist.new.to_command
      cmd.flags.lookup("skip-notarize").should_not be_nil
      cmd.flags.lookup("dmg").should be_nil
      cmd.flags.lookup("appimage").should be_nil
    end

    it "derives app name from entry point when no name is set" do
      cmd = LuneCLI::Commands::Dist.new
      cmd.app_name_for("src/main.cr").should eq("main")
    end

    it "uses config name as app name when set" do
      cmd = LuneCLI::Commands::Dist.new
      cmd.app_name_for("src/main.cr", "Demo").should eq("Demo")
    end

    it "derives the dist output path from app entry" do
      cmd = LuneCLI::Commands::Dist.new
      {% if flag?(:darwin) %}
        cmd.dist_path_for("src/main.cr").should eq("build/bin/main.dmg")
        cmd.dist_path_for("src/main.cr", "Demo").should eq("build/bin/Demo.dmg")
      {% elsif flag?(:linux) %}
        cmd.dist_path_for("src/main.cr").should eq("build/bin/main.AppImage")
        cmd.dist_path_for("src/main.cr", "Demo").should eq("build/bin/Demo.AppImage")
      {% end %}
    end

    {% if flag?(:darwin) %}
      it "info_plist_for includes CFBundleURLTypes when url_schemes are set" do
        cmd = ExposedBuildCommand.new
        plist = cmd.call_info_plist_for("src/main.cr", nil, nil, nil, ["myapp", "myapp2"])
        plist.should contain("CFBundleURLTypes")
        plist.should contain("<string>myapp</string>")
        plist.should contain("<string>myapp2</string>")
      end

      it "info_plist_for omits CFBundleURLTypes when url_schemes is empty" do
        cmd = ExposedBuildCommand.new
        plist = cmd.call_info_plist_for("src/main.cr")
        plist.should_not contain("CFBundleURLTypes")
      end

      it "write_default_entitlements creates a valid plist in the temp dir" do
        cmd = ExposedBuildCommand.new
        path = cmd.call_write_default_entitlements
        File.exists?(path).should be_true
        content = File.read(path)
        content.includes?("com.apple.security.cs.allow-jit").should be_true
        content.includes?("com.apple.security.network.client").should be_true
      end
    {% end %}

    {% if flag?(:linux) %}
      it "desktop_entry_for includes MimeType when url_schemes are set" do
        cmd = ExposedDistCommand.new
        entry = cmd.call_desktop_entry_for("myapp", ["myscheme", "myscheme2"])
        entry.should contain("MimeType=x-scheme-handler/myscheme;x-scheme-handler/myscheme2;")
      end

      it "desktop_entry_for omits MimeType when url_schemes is empty" do
        cmd = ExposedDistCommand.new
        entry = cmd.call_desktop_entry_for("myapp")
        entry.should_not contain("MimeType")
      end

      it "desktop_entry_for includes %u in Exec for URL passing" do
        cmd = ExposedDistCommand.new
        entry = cmd.call_desktop_entry_for("myapp")
        entry.should contain("Exec=myapp %u")
      end
    {% end %}
  end

  describe "_dev-error command" do
    it "is registered on the root command" do
      cmd = LuneCLI.root_command
      cmd.subcommands.has_key?("_dev-error").should be_true
    end

    it "is hidden from help output" do
      cmd = LuneCLI.root_command
      cmd.subcommands["_dev-error"].hidden.should be_true
    end

    it "escapes HTML entities in error text" do
      html = LuneCLI::Commands::DevError.new.build_html("a < b & c > d")
      html.includes?("&lt;").should be_true
      html.includes?("&amp;").should be_true
      html.includes?("&gt;").should be_true
    end

    it "does not leave raw angle brackets or ampersands in the output" do
      html = LuneCLI::Commands::DevError.new.build_html("<script>alert('xss')</script>")
      html.includes?("<script>").should be_false
      html.includes?("&lt;script&gt;").should be_true
    end

    it "includes the error message verbatim (after escaping)" do
      html = LuneCLI::Commands::DevError.new.build_html("syntax error on line 42")
      html.includes?("syntax error on line 42").should be_true
    end
  end

  describe "run command" do
    it "derives the built artifact path from the app entry" do
      cmd = LuneCLI::Commands::Run.new

      expected_output = {% if flag?(:darwin) %}
                          "build/bin/main.app"
                        {% elsif flag?(:win32) %}
                          "build\\bin\\main.exe"
                        {% else %}
                          "build/bin/main"
                        {% end %}

      cmd.artifact_path_for("main.cr").should eq(expected_output)
    end

    it "uses config name in artifact path when set" do
      cmd = LuneCLI::Commands::Run.new

      expected_output = {% if flag?(:darwin) %}
                          "build/bin/demo.app"
                        {% elsif flag?(:win32) %}
                          "build\\bin\\demo.exe"
                        {% else %}
                          "build/bin/demo"
                        {% end %}

      cmd.artifact_path_for("src/main.cr", "demo").should eq(expected_output)
    end

    it "returns false immediately when a run lock is already held for the same entry" do
      with_tempdir do |lock_dir|
        cmd = LuneCLI::Commands::Run.new
        slug = cmd.run_lock_slug("src/main.cr")
        held = Lune::SingleInstance.acquire(slug, lock_dir)
        held.should_not be_nil

        result = cmd.run(app_entry: "src/main.cr", lock_dir: lock_dir)
        result.should be_false

        held.try(&.close)
      end
    end

    it "run_lock_slug differs from dev_lock_slug for the same entry" do
      run_cmd = LuneCLI::Commands::Run.new
      dev_cmd = LuneCLI::Commands::Dev.new
      run_cmd.run_lock_slug("src/main.cr").should_not eq(dev_cmd.dev_lock_slug("src/main.cr"))
    end
  end

  describe "doctor command" do
    it "reports frontend deps as failing when node_modules is absent" do
      with_tempdir do |dir|
        cmd = LuneCLI::Commands::Doctor.new
        result = cmd.run(frontend_dir: dir, app_entry: "spec/fixtures/main.cr", output: IO::Memory.new)
        result.should be_false
      end
    end

    it "reports app entry as failing when the file does not exist" do
      with_tempdir do |dir|
        Dir.mkdir_p(File.join(dir, "node_modules"))
        cmd = LuneCLI::Commands::Doctor.new
        result = cmd.run(frontend_dir: dir, app_entry: File.join(dir, "nonexistent.cr"), output: IO::Memory.new)
        result.should be_false
      end
    end

    it "reads frontend_dir and app_entry from lune.yml" do
      with_tempdir do |dir|
        File.write(File.join(dir, "lune.yml"), "frontend:\n  dir: custom_fe\napp_entry: custom/main.cr\n")

        cmd = RecordingDoctorCommand.new
        Dir.cd(dir) do
          cmd.to_command.__execute_without_rescue_for_spec([] of String)
        end

        cmd.captured_frontend_dir.should eq("custom_fe")
        cmd.captured_app_entry.should eq("custom/main.cr")
      end
    end
  end
end
