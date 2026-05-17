require "file_utils"
require "json"

module LuneCLI
  module Commands
    class Build
      def to_command : Argy::Command
        config = LuneCLI::Config.load

        command = Argy::Command.new(
          use: "build",
          aliases: ["b"],
          short: "Build the Lune app",
          long: "Build frontend assets, then compile the configured Crystal app into a runnable artifact."
        )

        command.on_pre_run do |_cmd, _args|
          if error = validate_paths(frontend_dir: config.frontend.dir, app_entry: config.app_entry)
            raise Argy::Error.new(error)
          end
        end

        command.flags.bool("release", 'r', false, "Compile with --release optimizations")

        command.on_run do |cmd, _args|
          release = cmd.bool_flag("release")
          output_path = output_path_for(config.app_entry)

          Lune.logger.info { "Building frontend assets..." }
          success = run(frontend_dir: config.frontend.dir, app_entry: config.app_entry, output_path: output_path, release: release, build_cmd: config.frontend.build || DEFAULT_BUILD_CMD, icon: config.icon, sign: config.mac.sign)

          if success
            Lune.logger.info { "Built app: #{output_path}" }
          else
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

      def run(frontend_dir : String, app_entry : String, output_path : String, release : Bool = false, build_cmd : String = DEFAULT_BUILD_CMD, icon : String? = nil, sign : String? = nil) : Bool
        LuneCLI::Generator.generate_bindings(app_entry, frontend_dir)

        build_parts = build_cmd.split(' ', remove_empty: true)
        frontend_status = Process.run(
          build_parts[0],
          build_parts[1..],
          chdir: frontend_dir,
          input: Process::Redirect::Inherit,
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit
        )
        return false unless frontend_status.success?

        FileUtils.mkdir_p(BUILD_DIR)
        compiled_output_path = compiled_output_path_for(app_entry, output_path)
        prepare_output_path(output_path, compiled_output_path)

        crystal_args = ["build", app_entry, "-Dpreview_mt", "-Dexecution_context", "-o", compiled_output_path]
        crystal_args << "--release" if release

        app_status = Process.run(
          "crystal",
          crystal_args,
          input: Process::Redirect::Inherit,
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit
        )
        return false unless app_status.success?

        File.delete?("#{compiled_output_path}.dwarf")
        finalize_output(app_entry, output_path, icon)
        {% if flag?(:darwin) %}
          if identity = sign
            sign_app(output_path, identity)
          else
            Lune.logger.info { "No mac.sign set — notifications will use osascript fallback (set mac.sign in lune.yml to enable UNUserNotificationCenter)" }
          end
        {% end %}
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

      private def finalize_output(app_entry : String, output_path : String, icon : String? = nil) : Nil
        {% if flag?(:darwin) %}
          icon_name = nil
          if src = icon
            if File.exists?(src)
              icns_path = File.extname(src).downcase == ".png" ? png_to_icns(src) : src
              if icns_path
                icon_name = File.basename(icns_path)
                FileUtils.cp(icns_path, File.join(output_path, "Contents", "Resources", icon_name))
              end
            else
              Lune.logger.warn { "Icon file not found: #{src}" }
            end
          end
          plist_path = File.join(output_path, "Contents", "Info.plist")
          File.write(plist_path, info_plist_for(app_entry, icon_name))
        {% elsif flag?(:linux) %}
          if src = icon
            if File.exists?(src)
              FileUtils.cp(src, File.join(File.dirname(output_path), File.basename(src)))
            else
              Lune.logger.warn { "Icon file not found: #{src}" }
            end
          end
        {% end %}
      end

      {% if flag?(:darwin) %}
      private def sign_app(output_path : String, identity : String) : Nil
        result = Process.run(
          "codesign",
          ["--force", "--deep", "--options", "runtime", "--sign", identity, output_path],
          input: Process::Redirect::Close,
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit
        )
        Lune.logger.warn { "codesign failed — notifications will fall back to osascript" } unless result.success?
      end
      {% end %}

      protected def png_to_icns(png_path : String) : String?
        iconset_dir = File.join(Dir.tempdir, "lune-icon-#{Random.new.hex(6)}.iconset")
        icns_path = File.join(Dir.tempdir, "lune-icon-#{Random.new.hex(6)}.icns")
        Dir.mkdir_p(iconset_dir)

        sizes = {16 => ["1x", ""], 32 => ["2x", "1x"], 64 => ["2x"], 128 => ["1x", ""], 256 => ["2x", "1x"], 512 => ["2x", "1x"]}
        {
          {"icon_16x16.png", 16},
          {"icon_16x16@2x.png", 32},
          {"icon_32x32.png", 32},
          {"icon_32x32@2x.png", 64},
          {"icon_128x128.png", 128},
          {"icon_128x128@2x.png", 256},
          {"icon_256x256.png", 256},
          {"icon_256x256@2x.png", 512},
          {"icon_512x512.png", 512},
          {"icon_512x512@2x.png", 1024},
        }.each do |(name, size)|
          dest = File.join(iconset_dir, name)
          Process.run("sips", ["-z", size.to_s, size.to_s, png_path, "--out", dest],
            output: Process::Redirect::Close, error: Process::Redirect::Close)
        end

        result = Process.run("iconutil", ["-c", "icns", iconset_dir, "-o", icns_path],
          output: Process::Redirect::Close, error: Process::Redirect::Close)

        FileUtils.rm_rf(iconset_dir)

        if result.success?
          icns_path
        else
          Lune.logger.warn { "Failed to convert #{png_path} to .icns — is Xcode installed?" }
          nil
        end
      end

      private def info_plist_for(app_entry : String, icon_name : String? = nil) : String
        app_name = app_name_for(app_entry)
        icon_entry = icon_name ? "\n  <key>CFBundleIconFile</key>\n  <string>#{icon_name}</string>" : ""
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
          <true/>#{icon_entry}
        </dict>
        </plist>
        XML
      end
    end
  end
end
