require "file_utils"

module LuneCLI
  module Commands
    class Dist
      def to_command : Argy::Command
        config = LuneCLI::Config.load

        command = Argy::Command.new(
          use: "dist",
          short: "Package the built app for distribution",
          long: "Creates a platform-native distributable from the built app. " \
                "On macOS produces a DMG; on Linux produces an AppImage."
        )

        command.flags.bool("skip-notarize", nil, false, "Skip notarization (macOS only)")

        command.on_run do |cmd, _args|
          skip_notarize = cmd.bool_flag("skip-notarize")

          {% if flag?(:darwin) %}
            app_name = app_name_for(config.app_entry, config.name)
            app_path = File.join(BUILD_DIR, "#{app_name}.app")
            dmg_path = dist_path_for(config.app_entry, config.name)

            unless Dir.exists?(app_path)
              raise Argy::Error.new("#{app_path} not found — run `lune build` first")
            end

            Lune.logger.info { "Packaging #{app_name}.app into DMG..." }
            raise Argy::Error.new("DMG creation failed") unless create_dmg(app_path, dmg_path, app_name)
            Lune.logger.info { "DMG created: #{dmg_path}" }

            if config.mac.notarize && !skip_notarize
              notarize(dmg_path)
            elsif !config.mac.notarize
              Lune.logger.info { "Skipping notarization (set mac.notarize: true in lune.yml to enable)" }
            end
          {% elsif flag?(:linux) %}
            binary_name = app_name_for(config.app_entry, config.name)
            binary_path = File.join(BUILD_DIR, binary_name)

            unless File.file?(binary_path)
              raise Argy::Error.new("#{binary_path} not found — run `lune build` first")
            end

            appimage_path = dist_path_for(config.app_entry, config.name)
            Lune.logger.info { "Building AppImage for #{binary_name}..." }
            raise Argy::Error.new("AppImage creation failed") unless create_appimage(binary_path, appimage_path, binary_name, config)
            Lune.logger.info { "AppImage created: #{appimage_path}" }
          {% else %}
            raise Argy::Error.new("lune dist is not yet supported on this platform")
          {% end %}
        end

        command
      end

      def app_name_for(app_entry : String, name : String? = nil) : String
        name || File.basename(app_entry, File.extname(app_entry))
      end

      def dist_path_for(app_entry : String, name : String? = nil) : String
        base = app_name_for(app_entry, name)
        {% if flag?(:darwin) %}
          File.join(BUILD_DIR, "#{base}.dmg")
        {% elsif flag?(:linux) %}
          File.join(BUILD_DIR, "#{base}.AppImage")
        {% else %}
          File.join(BUILD_DIR, base)
        {% end %}
      end

      {% if flag?(:darwin) %}
        def create_dmg(app_path : String, dmg_path : String, vol_name : String) : Bool
          staging = File.join(Dir.tempdir, "lune_dmg_#{Random.new.hex(6)}")
          Dir.mkdir_p(staging)

          begin
            FileUtils.cp_r(app_path, File.join(staging, File.basename(app_path)))
            File.symlink("/Applications", File.join(staging, "Applications"))
            File.delete?(dmg_path)

            Process.run(
              "hdiutil",
              ["create",
               "-srcfolder", staging,
               "-volname", vol_name,
               "-fs", "HFS+",
               "-fsargs", "-c c=64,a=16,e=16",
               "-format", "UDZO",
               "-imagekey", "zlib-level=9",
               dmg_path],
              input: Process::Redirect::Close,
              output: Process::Redirect::Inherit,
              error: Process::Redirect::Inherit
            ).success?
          ensure
            FileUtils.rm_rf(staging)
          end
        end

        def notarize(dmg_path : String) : Nil
          apple_id = ENV["APPLE_ID"]?
          password = ENV["APPLE_PASSWORD"]?
          team_id = ENV["APPLE_TEAM_ID"]?

          unless apple_id && password && team_id
            Lune.logger.warn { "mac.notarize requires APPLE_ID, APPLE_PASSWORD, and APPLE_TEAM_ID env vars — skipping" }
            return
          end

          Lune.logger.info { "Submitting #{File.basename(dmg_path)} for notarization (this may take a few minutes)..." }
          result = Process.run(
            "xcrun",
            ["notarytool", "submit", dmg_path,
             "--apple-id", apple_id,
             "--password", password,
             "--team-id", team_id,
             "--wait"],
            input: Process::Redirect::Close,
            output: Process::Redirect::Inherit,
            error: Process::Redirect::Inherit
          )

          unless result.success?
            Lune.logger.warn { "Notarization submission failed — check output above" }
            return
          end

          Lune.logger.info { "Stapling notarization ticket..." }
          staple = Process.run(
            "xcrun",
            ["stapler", "staple", dmg_path],
            input: Process::Redirect::Close,
            output: Process::Redirect::Inherit,
            error: Process::Redirect::Inherit
          )

          if staple.success?
            Lune.logger.info { "Notarization complete — #{File.basename(dmg_path)} is ready to distribute" }
          else
            Lune.logger.warn { "Stapling failed — DMG was notarized but ticket was not attached" }
          end
        end
      {% end %}

      {% if flag?(:linux) %}
        def create_appimage(binary_path : String, appimage_path : String, app_name : String, config : LuneCLI::Config) : Bool
          appdir = File.join(BUILD_DIR, "#{app_name}.AppDir")

          begin
            FileUtils.rm_rf(appdir)
            FileUtils.mkdir_p(File.join(appdir, "usr", "bin"))

            FileUtils.cp(binary_path, File.join(appdir, "usr", "bin", app_name))
            File.chmod(File.join(appdir, "usr", "bin", app_name), 0o755)

            File.write(File.join(appdir, "AppRun"), apprun_for(app_name))
            File.chmod(File.join(appdir, "AppRun"), 0o755)

            File.write(File.join(appdir, "#{app_name}.desktop"), desktop_entry_for(app_name, config.url_schemes))

            if icon_src = config.icon
              if File.exists?(icon_src) && File.extname(icon_src).downcase == ".png"
                FileUtils.cp(icon_src, File.join(appdir, "#{app_name}.png"))
              end
            end

            check = Process.run("which", ["appimagetool"],
              input: Process::Redirect::Close,
              output: Process::Redirect::Close,
              error: Process::Redirect::Close)
            unless check.success?
              raise Argy::Error.new(
                "appimagetool not found — download the binary for your arch from " \
                "https://github.com/AppImage/appimagetool/releases/tag/continuous and place it in your PATH"
              )
            end

            File.delete?(appimage_path)

            Process.run(
              "appimagetool",
              [appdir, appimage_path],
              input: Process::Redirect::Close,
              output: Process::Redirect::Inherit,
              error: Process::Redirect::Inherit
            ).success?
          ensure
            FileUtils.rm_rf(appdir)
          end
        end

        private def apprun_for(app_name : String) : String
          <<-SH
        #!/bin/sh
        SELF=$(readlink -f "$0")
        HERE=${SELF%/*}
        exec "${HERE}/usr/bin/#{app_name}" "$@"
        SH
        end

        private def desktop_entry_for(app_name : String, url_schemes : Array(String) = [] of String) : String
          mime = url_schemes.empty? ? "" : "\nMimeType=#{url_schemes.map { |s| "x-scheme-handler/#{s}" }.join(";")};"
          <<-DESKTOP
        [Desktop Entry]
        Name=#{app_name}
        Exec=#{app_name} %u
        Icon=#{app_name}
        Type=Application
        Categories=Utility;#{mime}
        DESKTOP
        end
      {% end %}
    end
  end
end
