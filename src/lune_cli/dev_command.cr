require "uri"
require "socket"

module LuneCLI
  class DevCommand
    DEFAULT_DEV_URL = "http://localhost:5173"
    DEV_BINARY      = ".lune-dev"

    def to_command : Argy::Command
      command = Argy::Command.new(
        use: "dev",
        aliases: ["d"],
        short: "Run the Lune app in dev mode",
        long: "Starts the Vite dev server and the Crystal app together. Kills the dev server when the app exits."
      )

      command.flags.string("dev-url", nil, DEFAULT_DEV_URL, "frontend development URL")

      command.on_pre_run do |cmd, _args|
        frontend_dir = cmd.string_flag("frontend-dir")
        app_entry = cmd.string_flag("app-entry")

        if error = validate_paths(frontend_dir: frontend_dir, app_entry: app_entry)
          Lune.logger.error { error }
          raise Argy::Error.new(error)
        end
      end

      command.on_run do |cmd, _args|
        frontend_dir = cmd.string_flag("frontend-dir")
        app_entry = cmd.string_flag("app-entry")
        dev_url = cmd.string_flag("dev-url")

        unless run(frontend_dir: frontend_dir, app_entry: app_entry, dev_url: dev_url)
          Lune.logger.error { "dev failed" }
          raise Argy::Error.new("dev failed")
        end
      end

      command
    end

    def validate_paths(frontend_dir : String, app_entry : String) : String?
      return "Frontend directory not found: #{frontend_dir}" unless Dir.exists?(frontend_dir)
      return "App entry file not found: #{app_entry}" unless File.file?(app_entry)

      nil
    end

    def run(frontend_dir : String, app_entry : String, dev_url : String, watcher : FileWatcher = FileWatcher.new) : Bool
      LuneCLI.pregen_runtime_js(frontend_dir)

      Lune.logger.info { "Starting Vite dev server in #{frontend_dir}..." }
      vite = Process.new(
        NPM_CMD,
        ["run", "dev"],
        chdir: frontend_dir,
        input: Process::Redirect::Close,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )

      unless wait_for_url(dev_url)
        Lune.logger.warn { "Timed out waiting for dev server at #{dev_url}" }
        vite.terminate
        vite.wait
        return false
      end

      # Merge LUNE_DEV_URL into the current environment rather than replacing
      # it entirely. Passing only a single-key Hash to Process.run drops PATH,
      # HOME, CRYSTAL_PATH, and everything else the child process needs.
      env = ENV.to_h.merge({"LUNE_DEV_URL" => dev_url})
      src_dir = File.dirname(app_entry)

      begin
        loop do
          Lune.logger.info { "Compiling #{app_entry}..." }
          compiled = Process.run(
            "crystal",
            ["build", app_entry, "-o", DEV_BINARY, "-Dpreview_mt"],
            env: env,
            input: Process::Redirect::Close,
            output: Process::Redirect::Inherit,
            error: Process::Redirect::Inherit
          )

          unless compiled.success?
            Lune.logger.error { "Compilation failed, waiting for changes..." }
            watcher.wait_for_change(src_dir)
            next
          end

          Lune.logger.info { "Starting app..." }
          app = Process.new(
            "./#{DEV_BINARY}",
            env: env,
            input: Process::Redirect::Inherit,
            output: Process::Redirect::Inherit,
            error: Process::Redirect::Inherit
          )

          if watcher.watch(app, src_dir)
            Lune.logger.info { "Change detected, restarting..." }
          else
            break
          end
        end
      ensure
        File.delete(DEV_BINARY) rescue nil
        File.delete("#{DEV_BINARY}.dwarf") rescue nil
      end

      Lune.logger.info { "App exited. Stopping dev server..." }
      vite.terminate
      vite.wait

      true
    end

    private def wait_for_url(url : String, timeout : Time::Span = 30.seconds) : Bool
      uri = URI.parse(url)
      host = uri.host || "127.0.0.1"
      port = uri.port || 5173
      deadline = Time.instant + timeout

      while Time.instant < deadline
        begin
          TCPSocket.new(host, port).close
          return true
        rescue IO::Error
          sleep 200.milliseconds
        end
      end

      false
    end
  end
end
