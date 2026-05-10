require "file_utils"
require "json"
require "../lune"

module LuneCLI
  class BuildCommand
    BUILD_DIR = File.join("build", "bin")

    def to_command : Argy::Command
      command = Argy::Command.new(
        use: "build",
        aliases: ["b"],
        short: "Build the Lune app",
        long: "Build frontend assets, then compile the configured Crystal app into a runnable artifact."
      )

      command.on_pre_run do |cmd, _args|
        frontend_dir = cmd.string_flag("frontend-dir")
        app_entry = cmd.string_flag("app-entry")

        if error = validate_paths(frontend_dir: frontend_dir, app_entry: app_entry)
          Lune.logger.error { error }
          raise Argy::Error.new(error)
        end
      end

      command.flags.bool("release", 'r', false, "Compile with --release optimizations")

      command.on_run do |cmd, _args|
        frontend_dir = cmd.string_flag("frontend-dir")
        app_entry = cmd.string_flag("app-entry")
        release = cmd.bool_flag("release")
        output_path = output_path_for(app_entry)

        Lune.logger.info { "Building frontend assets..." }
        success = run(frontend_dir: frontend_dir, app_entry: app_entry, output_path: output_path, release: release)

        if success
          Lune.logger.info { "Built app: #{output_path}" }
        else
          Lune.logger.error { "build failed" }
          raise Argy::Error.new("build failed")
        end
      end

      command
    end

    def output_path_for(app_entry : String) : String
      app_name = app_name_for(app_entry)
      {% if flag?(:darwin) %}
        File.join(BUILD_DIR, "#{app_name}.app")
      {% else %}
        File.join(BUILD_DIR, app_name)
      {% end %}
    end

    def validate_paths(frontend_dir : String, app_entry : String) : String?
      return "Frontend directory not found: #{frontend_dir}" unless Dir.exists?(frontend_dir)
      return "App entry file not found: #{app_entry}" unless File.file?(app_entry)

      nil
    end

    def run(frontend_dir : String, app_entry : String, output_path : String, release : Bool = false) : Bool
      # Pre-generate JS so the bundler can resolve lunejs imports before `npm run build`.
      # Binding names are unavailable here — the Proxy fallback in App.js handles runtime dispatch.
      LuneCLI.pregen_runtime_js(frontend_dir)

      frontend_status = Process.run(
        NPM_CMD,
        ["run", "build"],
        chdir: frontend_dir,
        input: Process::Redirect::Inherit,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )
      return false unless frontend_status.success?

      FileUtils.mkdir_p(BUILD_DIR)
      compiled_output_path = compiled_output_path_for(app_entry, output_path)
      prepare_output_path(output_path, compiled_output_path)

      crystal_args = ["build", app_entry, "-Dpreview_mt", "-o", compiled_output_path]
      crystal_args << "--release" if release

      app_status = Process.run(
        "crystal",
        crystal_args,
        input: Process::Redirect::Inherit,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )
      return false unless app_status.success?

      File.delete("#{compiled_output_path}.dwarf") rescue nil
      finalize_output(app_entry, output_path)
      true
    end

    private def app_name_for(app_entry : String) : String
      File.basename(app_entry, File.extname(app_entry))
    end

    private def compiled_output_path_for(app_entry : String, output_path : String) : String
      {% if flag?(:darwin) %}
        File.join(output_path, "Contents", "MacOS", app_name_for(app_entry))
      {% else %}
        output_path
      {% end %}
    end

    private def prepare_output_path(output_path : String, compiled_output_path : String) : Nil
      {% if flag?(:darwin) %}
        FileUtils.rm_rf(output_path)
        FileUtils.mkdir_p(File.dirname(compiled_output_path))
        FileUtils.mkdir_p(File.join(output_path, "Contents", "Resources"))
      {% else %}
        FileUtils.mkdir_p(File.dirname(compiled_output_path))
      {% end %}
    end

    private def finalize_output(app_entry : String, output_path : String) : Nil
      {% if flag?(:darwin) %}
        plist_path = File.join(output_path, "Contents", "Info.plist")
        File.write(plist_path, info_plist_for(app_entry))
      {% end %}
    end

    private def info_plist_for(app_entry : String) : String
      app_name = app_name_for(app_entry)
      <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>en</string>
        <key>CFBundleExecutable</key>
        <string>#{app_name}</string>
        <key>CFBundleIdentifier</key>
        <string>dev.lune.#{app_name.gsub('_', '-')}</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>#{app_name}</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>CFBundleShortVersionString</key>
        <string>#{Lune::VERSION}</string>
        <key>CFBundleVersion</key>
        <string>#{Lune::VERSION}</string>
        <key>NSHighResolutionCapable</key>
        <true/>
      </dict>
      </plist>
      XML
    end
  end
end
