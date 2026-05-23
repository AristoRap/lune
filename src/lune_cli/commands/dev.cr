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
          if error = validate_paths(config)
            raise Argy::Error.new(error)
          end
        end

        command.on_run do |_cmd, _args|
          unless run(config)
            raise Argy::Error.new("dev failed")
          end
        end

        command
      end

      def validate_paths(config : LuneCLI::Config) : String?
        return "Frontend directory not found: #{config.frontend.dir}" unless Dir.exists?(config.frontend.dir)
        return "App entry file not found: #{config.app_entry}" unless File.file?(config.app_entry)

        nil
      end

      def dev_lock_slug(app_entry : String) : String
        abs = File.expand_path(app_entry)
        "dev-" + Lune::SingleInstance.slug(abs)
      end

      def run(
        config : LuneCLI::Config,
        watcher : FileWatcher = FileWatcher.new,
        lock_dir : String = File.join(Path.home, ".lune"),
      ) : Bool
        frontend_dir = config.frontend.dir
        app_entry = config.app_entry
        dev_cmd = config.frontend.dev.cmd || DEFAULT_DEV_CMD
        dev_url = config.frontend.dev.url

        lock_file = Lune::SingleInstance.acquire(dev_lock_slug(app_entry), lock_dir)
        unless lock_file
          Lune.logger.error { "Another 'lune dev' is already running for #{app_entry}" }
          return false
        end

        Lune.logger.info { "Starting frontend dev server in #{frontend_dir} (#{dev_cmd})..." }

        # Anchor every descendant lune dev spawns (cmd/npm/vite/node, the
        # compiled .lune-dev app, the error-overlay window) to a Job Object
        # by putting lune.exe itself in it. The job has no breakaway flag,
        # so Windows forces every descendant into the same job. When lune.exe
        # dies for any reason (Ctrl-C, taskkill, crash), KILL_ON_JOB_CLOSE
        # atomically kills the whole tree. See Native::ProcessGroup.
        {% if flag?(:win32) %}
          dev_job = Lune::Native::ProcessGroup.create_and_attach_self
        {% end %}

        dev_parts = dev_cmd.split(' ', remove_empty: true)
        dev_program, dev_args = LuneCLI::ProcessSpawn.wrap(dev_parts[0], dev_parts[1..])
        vite = Process.new(
          dev_program, dev_args,
          chdir: frontend_dir,
          input: Process::Redirect::Close,
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit
        )

        unless wait_for_url(dev_url)
          Lune.logger.warn { "Timed out waiting for dev server at #{dev_url}" }
          stop_dev_server(vite)
          return false
        end

        # Merge LUNE_DEV_URL into the current environment rather than replacing
        # it entirely. Passing only a single-key Hash to Process.run drops PATH,
        # HOME, CRYSTAL_PATH, and everything else the child process needs.
        env = ENV.to_h.merge({Lune::ENV_DEV_URL => dev_url, Lune::ENV_FRONTEND_DIR => frontend_dir})
        # Propagate --debug (set on the CLI's root command) into the spawned
        # user-app binary via LUNE_LOG; the binary's own Lune.default_logger
        # reads it on startup.
        env["LUNE_LOG"] = "debug" if Lune.logger.level == Log::Severity::Debug
        src_dir = File.dirname(app_entry)
        lune_bin = Process.executable_path || "lune"
        error_display : Process? = nil

        begin
          loop do
            Lune.logger.info { "Compiling #{app_entry}..." }
            stderr_buf = IO::Memory.new
            compiled = Process.run(
              "crystal",
              ["build", app_entry, "-o", DEV_BINARY, "-Dpreview_mt", "-Dexecution_context", "-Dlune_dev"],
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
        stop_dev_server(vite)

        true
      end

      # Kills vite and every descendant it spawned. On Windows, `vite` is a
      # `cmd /c npm run dev` wrapper, and Process.terminate (TerminateProcess)
      # only kills the cmd.exe leader -- npm.cmd/node.exe orphan and keep
      # holding the dev-server port. taskkill /T walks the tree. The job
      # object that lune.exe is attached to remains as an ungraceful-exit
      # safety net (KILL_ON_JOB_CLOSE) -- we deliberately don't terminate it
      # here because that would kill lune.exe too.
      private def stop_dev_server(vite : Process) : Nil
        {% if flag?(:win32) %}
          Process.run("taskkill", ["/F", "/T", "/PID", vite.pid.to_s],
            input: Process::Redirect::Close,
            output: Process::Redirect::Close,
            error: Process::Redirect::Close)
          vite.wait rescue nil
        {% else %}
          vite.terminate
          vite.wait
        {% end %}
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
