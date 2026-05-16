require "../file_watcher"
require "uri"
require "socket"

module LuneCLI
  module Commands
    class Dev
      def to_command : Argy::Command
        config = LuneCLI::Config.load

        command = Argy::Command.new(
          use: "dev",
          aliases: ["d"],
          short: "Run the Lune app in dev mode",
          long: "Starts the frontend dev server and the Crystal app together. Kills the dev server when the app exits."
        )

        command.on_pre_run do |_cmd, _args|
          if error = validate_paths(frontend_dir: config.frontend.dir, app_entry: config.app_entry)
            raise Argy::Error.new(error)
          end
        end

        command.on_run do |_cmd, _args|
          unless run(frontend_dir: config.frontend.dir, app_entry: config.app_entry, dev_cmd: config.frontend.dev.cmd || DEFAULT_DEV_CMD, dev_url: config.frontend.dev.url)
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

      def dev_lock_slug(app_entry : String) : String
        abs = File.expand_path(app_entry)
        "dev-" + Lune::SingleInstance.slug(abs)
      end

      def run(
        frontend_dir : String,
        app_entry : String,
        dev_url : String,
        dev_cmd : String = DEFAULT_DEV_CMD,
        watcher : FileWatcher = FileWatcher.new,
        lock_dir : String = File.join(Path.home, ".lune"),
      ) : Bool
        lock_file = Lune::SingleInstance.acquire(dev_lock_slug(app_entry), lock_dir)
        unless lock_file
          Lune.logger.error { "Another 'lune dev' is already running for #{app_entry}" }
          return false
        end

        Lune.logger.info { "Starting frontend dev server in #{frontend_dir} (#{dev_cmd})..." }
        dev_parts = dev_cmd.split(' ', remove_empty: true)
        vite = Process.new(
          dev_parts[0],
          dev_parts[1..],
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
        env = ENV.to_h.merge({Lune::ENV_DEV_URL => dev_url, Lune::ENV_FRONTEND_DIR => frontend_dir})
        src_dir = File.dirname(app_entry)
        lune_bin = Process.executable_path || "lune"
        error_display : Process? = nil

        begin
          loop do
            Lune.logger.info { "Compiling #{app_entry}..." }
            stderr_buf = IO::Memory.new
            compiled = Process.run(
              "crystal",
              ["build", app_entry, "-o", DEV_BINARY, "-Dpreview_mt", "-Dexecution_context"],
              env: env,
              input: Process::Redirect::Close,
              output: Process::Redirect::Inherit,
              error: stderr_buf
            )

            unless compiled.success?
              error_text = stderr_buf.to_s
              STDERR.print(error_text)
              error_display.try { |p| p.terminate(graceful: false) rescue nil }
              ed = Process.new(
                lune_bin, ["_dev-error"],
                input: Process::Redirect::Pipe,
                output: Process::Redirect::Inherit,
                error: Process::Redirect::Inherit
              )
              ed.input.print(error_text)
              ed.input.close
              error_display = ed
              Lune.logger.error { "Compilation failed, waiting for changes..." }
              watcher.wait_for_change(src_dir)
              next
            end

            error_display.try { |p| p.terminate(graceful: false) rescue nil }
            error_display = nil
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
          error_display.try { |p| p.terminate(graceful: false) rescue nil }
          File.delete?(DEV_BINARY)
          File.delete?("#{DEV_BINARY}.dwarf")
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
end
