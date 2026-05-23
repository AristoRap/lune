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
          if error = validate_paths(config)
            raise Argy::Error.new(error)
          end
        end

        command.flags.bool("release", 'r', false, "Compile with --release optimizations")

        command.on_run do |cmd, _args|
          release = cmd.bool_flag("release")

          Lune.logger.info { "Building frontend assets..." }
          success = run(config, release: release)

          if success
            Lune.logger.info { "Built app: #{output_path_for(config.app_entry, config.name)}" }
          else
            raise Argy::Error.new("build failed")
          end
        end

        command
      end

      def output_path_for(app_entry : String, name : String? = nil) : String
        bundle = bundle_name_for(app_entry, name)
        {% if flag?(:darwin) %}
          File.join(BUILD_DIR, "#{bundle}.app")
        {% elsif flag?(:win32) %}
          File.join(BUILD_DIR, "#{bundle}.exe")
        {% else %}
          File.join(BUILD_DIR, bundle)
        {% end %}
      end

      def bundle_name_for(app_entry : String, name : String? = nil) : String
        name || File.basename(app_entry, File.extname(app_entry))
      end

      def validate_paths(config : LuneCLI::Config) : String?
        return "Frontend directory not found: #{config.frontend.dir}" unless Dir.exists?(config.frontend.dir)
        return "App entry file not found: #{config.app_entry}" unless File.file?(config.app_entry)

        nil
      end

      def run(config : LuneCLI::Config = LuneCLI::Config.new, release : Bool = false) : Bool
        app_entry = config.app_entry
        output_path = output_path_for(app_entry, config.name)
        frontend_dir = config.frontend.dir
        build_cmd = config.frontend.build || DEFAULT_BUILD_CMD

        LuneCLI::Generator.generate_bindings(app_entry, frontend_dir)

        build_parts = build_cmd.split(' ', remove_empty: true)
        program, run_args = LuneCLI::ProcessSpawn.wrap(build_parts[0], build_parts[1..])
        frontend_status = Process.run(
          program, run_args,
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

        {% if flag?(:win32) %}
          # Embed the app icon in the .exe via a tiny .rc → .res compile.
          # Falls through silently if no icon is configured, the file is
          # missing, or rc.exe isn't on PATH (no MSVC SDK).
          if res_path = compile_win_icon_resource(config.icon)
            crystal_args.concat(["--link-flags", res_path])
          end
        {% end %}

        # Bake `lune.yml`'s `name:` into the binary as Lune::APP_NAME via
        # `{{ env("LUNE_APP_NAME") }}` at compile time. Defaults to the app
        # entry's basename when `name:` is unset.
        build_env = ENV.to_h.merge({Lune::ENV_APP_NAME => config.name || binary_name_for(app_entry)})

        app_status = Process.run(
          "crystal",
          crystal_args,
          env: build_env,
          input: Process::Redirect::Inherit,
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit
        )
        return false unless app_status.success?

        File.delete?("#{compiled_output_path}.dwarf")
        finalize_output(output_path, config)
        {% if flag?(:darwin) %}
          if identity = config.mac.sign
            sign_app(output_path, identity, config.mac.entitlements)
          else
            Lune.logger.info { "No mac.sign set — notifications will use osascript fallback (set mac.sign in lune.yml to enable UNUserNotificationCenter)" }
          end
        {% end %}
        true
      end

      private def binary_name_for(app_entry : String) : String
        File.basename(app_entry, File.extname(app_entry))
      end

      private def compiled_output_path_for(app_entry : String, output_path : String) : String
        {% if flag?(:darwin) %}
          File.join(output_path, "Contents", "MacOS", binary_name_for(app_entry))
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

      {% if flag?(:win32) %}
        # Generate a Win32 .res file containing the configured icon, ready
        # to be passed to the MSVC linker via crystal build's --link-flags.
        # Returns nil (silently) if: no icon configured, file missing, or
        # rc.exe not on PATH. The build still succeeds — just without the
        # embedded icon.
        private def compile_win_icon_resource(icon : String?) : String?
          return nil unless src = icon
          unless File.exists?(src)
            Lune.logger.warn { "Icon file not found: #{src}" }
            return nil
          end
          # .ico is what Windows expects. We don't auto-convert from .png
          # because Crystal lacks a PNG library in stdlib; require the
          # user to supply a .ico directly. Could shell out to ImageMagick
          # later if needed.
          unless File.extname(src).downcase == ".ico"
            Lune.logger.warn { "Win32 icon must be .ico (got #{File.extname(src)}); skipping embed" }
            return nil
          end

          rc_path  = File.join(Dir.tempdir, "lune-icon-#{Random.new.hex(6)}.rc")
          res_path = File.join(Dir.tempdir, "lune-icon-#{Random.new.hex(6)}.res")
          # `1 ICON "..."` — resource ID 1 is the convention Windows
          # Explorer reads for the .exe's display icon.
          File.write(rc_path, "1 ICON \"#{File.expand_path(src).gsub('\\', "\\\\")}\"\n")
          status = Process.run("rc", ["/nologo", "/fo", res_path, rc_path],
            input: Process::Redirect::Close,
            output: Process::Redirect::Inherit,
            error: Process::Redirect::Inherit)
          File.delete?(rc_path)
          unless status.success?
            Lune.logger.warn { "rc.exe failed or missing — skipping icon embed (install MSVC Build Tools to fix)" }
            File.delete?(res_path)
            return nil
          end
          res_path
        rescue ex : File::Error | IO::Error
          Lune.logger.warn { "Icon embed failed: #{ex.message}" }
          nil
        end
      {% end %}

      private def finalize_output(output_path : String, config : LuneCLI::Config = LuneCLI::Config.new) : Nil
        {% if flag?(:darwin) %}
          icon_name = nil
          if src = config.icon
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
          File.write(plist_path, info_plist_for(config.app_entry, icon_name, config.name, config.mac.bundle_id, config.url_schemes))
        {% elsif flag?(:linux) %}
          if src = config.icon
            if File.exists?(src)
              FileUtils.cp(src, File.join(File.dirname(output_path), File.basename(src)))
            else
              Lune.logger.warn { "Icon file not found: #{src}" }
            end
          end
        {% end %}
      end

      {% if flag?(:darwin) %}
        private def sign_app(output_path : String, identity : String, entitlements : String? = nil) : Nil
          ents_path = resolve_entitlements(entitlements)
          args = ["--force", "--deep", "--options", "runtime",
                  "--entitlements", ents_path,
                  "--sign", identity, output_path]
          result = Process.run(
            "codesign", args,
            input: Process::Redirect::Close,
            output: Process::Redirect::Inherit,
            error: Process::Redirect::Inherit
          )
          Lune.logger.warn { "codesign failed — notifications will fall back to osascript" } unless result.success?
        end

        private def resolve_entitlements(path : String?) : String
          if p = path
            return p if File.exists?(p)
            Lune.logger.warn { "Entitlements file not found: #{p} — using defaults" }
          end
          write_default_entitlements
        end

        protected def write_default_entitlements : String
          tmp = File.join(Dir.tempdir, "lune-entitlements-#{Random.new.hex(6)}.plist")
          File.write(tmp, DEFAULT_ENTITLEMENTS_PLIST)
          tmp
        end

        DEFAULT_ENTITLEMENTS_PLIST = <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>com.apple.security.cs.allow-jit</key>
        <true/>
        <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
        <true/>
        <key>com.apple.security.network.client</key>
        <true/>
      </dict>
      </plist>
      XML
      {% end %}

      protected def png_to_icns(png_path : String) : String?
        iconset_dir = File.join(Dir.tempdir, "lune-icon-#{Random.new.hex(6)}.iconset")
        icns_path = File.join(Dir.tempdir, "lune-icon-#{Random.new.hex(6)}.icns")
        Dir.mkdir_p(iconset_dir)

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

      private def info_plist_for(app_entry : String, icon_name : String? = nil, display_name : String? = nil, bundle_id : String? = nil, url_schemes : Array(String) = [] of String) : String
        binary_name = binary_name_for(app_entry)
        app_name = display_name || binary_name
        identifier = bundle_id || "dev.lune.#{binary_name.gsub('_', '-')}"
        icon_entry = icon_name ? "\n  <key>CFBundleIconFile</key>\n  <string>#{icon_name}</string>" : ""
        url_types_entry = url_schemes.empty? ? "" : build_url_types_plist(url_schemes, identifier)
        <<-XML
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>CFBundleDevelopmentRegion</key>
          <string>en</string>
          <key>CFBundleExecutable</key>
          <string>#{binary_name}</string>
          <key>CFBundleIdentifier</key>
          <string>#{identifier}</string>
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
          <true/>#{icon_entry}#{url_types_entry}
        </dict>
        </plist>
        XML
      end

      private def build_url_types_plist(schemes : Array(String), identifier : String) : String
        String.build do |s|
          s << "\n  <key>CFBundleURLTypes</key>\n  <array>"
          schemes.each do |scheme|
            s << "\n    <dict>"
            s << "\n      <key>CFBundleURLName</key>"
            s << "\n      <string>#{identifier}.#{scheme}</string>"
            s << "\n      <key>CFBundleURLSchemes</key>"
            s << "\n      <array>"
            s << "\n        <string>#{scheme}</string>"
            s << "\n      </array>"
            s << "\n    </dict>"
          end
          s << "\n  </array>"
        end
      end
    end
  end
end
