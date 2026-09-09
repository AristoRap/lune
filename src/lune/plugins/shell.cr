module Lune
  module Plugins
    class Shell < Lune::Plugin
      include Lune::Bindable
      include Plugin::Lifecycle

      DESCRIPTOR = Descriptor.new(id: :shell, label: "Shell", deps: [:stream])

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @processes = {} of String => Process
      @stdins = {} of String => IO::FileDescriptor
      @mu = Mutex.new

      # spawn calls @app.async three times to start the stdout/stderr/wait
      # pumps. On Windows those run through Channel#receive in the Parallel
      # scheduler — illegal from the webview Isolated thread. async routes
      # the callback through @async_pool so the spawn is safe.
      @[Lune::Bind(async: true)]
      def spawn(command : String, args : Array(String), cwd : String? = nil, env : Hash(String, String?)? = nil) : String
        with_execution_context(command, cwd) { spawn_proc(@app, command, args, cwd, env) }
      end

      @[Lune::Bind]
      def kill(pid : String) : Nil
        @mu.synchronize do
          @processes[pid]?.try(&.terminate)
          @stdins.delete(pid).try { |io| io.close rescue nil }
        end
      end

      @[Lune::Bind]
      def write(pid : String, text : String) : Nil
        @mu.synchronize { @stdins[pid]? }.try { |io| io.print(text) rescue nil }
      end

      @[Lune::Bind]
      def close_stdin(pid : String) : Nil
        @mu.synchronize { @stdins.delete(pid) }.try { |io| io.close rescue nil }
      end

      @[Lune::Bind(async: true)]
      def list : Array(String)
        @mu.synchronize { @processes.keys }
      end

      # Blocking async binding — collects all output then resolves.
      # Avoids the Stream listener race that occurs when a process exits
      # before the JS .then() callback can register Stream handlers.
      @[Lune::Bind(async: true)]
      def run(command : String, args : Array(String), cwd : String? = nil, env : Hash(String, String?)? = nil) : NamedTuple(stdout: String, stderr: String, code: Int32)
        out_buf = IO::Memory.new
        err_buf = IO::Memory.new
        status = with_execution_context(command, cwd) do
          Shell.with_win32_cmd_fallback(command, args) do |c, a|
            Process.run(c, args: a, chdir: cwd, env: env, output: out_buf, error: err_buf)
          end
        end
        code = status.exit_code? || -1
        {stdout: out_buf.to_s, stderr: err_buf.to_s, code: code}
      end

      # Yields (cmd, argv) to the block as-is. On Win32, if the block raises
      # File::NotFoundError, yields again with ("cmd", ["/c", cmd] + argv) —
      # which handles cmd builtins (echo, dir, type, cd, more, ...) and
      # .cmd/.bat shims (npm.cmd, yarn.cmd) that CreateProcess can't exec
      # directly. POSIX path is unchanged; any error propagates.
      def self.with_win32_cmd_fallback(cmd : String, argv : Array(String), &)
        yield cmd, argv
      rescue ex : File::NotFoundError
        {% if flag?(:win32) %}
          yield "cmd", ["/c", cmd] + argv
        {% else %}
          raise ex
        {% end %}
      end

      def shutdown : Nil
        procs = @mu.synchronize { @processes.dup }
        procs.each_value { |pr| pr.terminate rescue nil }
        @mu.synchronize do
          @processes.clear
          @stdins.each_value { |io| io.close rescue nil }
          @stdins.clear
        end
      end

      def js_helpers : String
        bm = BRIDGE_MARKER
        <<-JS
          listen(pid, opts) {
            var b = window.#{bm};
            opts = opts || {};
            var stdout = opts.stdout, stderr = opts.stderr, exit = opts.exit;
            var prefix = "shell:" + pid + ":", disposed = false;
            function onStdout(d) { if (!disposed) stdout(d); }
            function onStderr(d) { if (!disposed) stderr(d); }
            function dispose() {
              if (disposed) return;
              disposed = true;
              if (stdout) b.stOff(prefix + "stdout", onStdout);
              if (stderr) b.stOff(prefix + "stderr", onStderr);
              b.stOff(prefix + "exit", onExit);
            }
            function onExit(d) {
              if (disposed) return;
              dispose();
              if (exit) exit(d);
            }
            if (stdout) b.stOn(prefix + "stdout", onStdout);
            if (stderr) b.stOn(prefix + "stderr", onStderr);
            b.stOn(prefix + "exit", onExit);
            return dispose;
          },
          unlisten(pid) {
            var b = window.#{bm};
            b.stOff("shell:" + pid + ":stdout");
            b.stOff("shell:" + pid + ":stderr");
            b.stOff("shell:" + pid + ":exit");
          },
        JS
      end

      def dts_helpers : String
        <<-DTS
          listen(pid: string, opts: { stdout?: (data: { line: string }) => void; stderr?: (data: { line: string }) => void; exit?: (data: { code: number }) => void }): () => void;
          unlisten(pid: string): void;
        DTS
      end

      # Validate cwd before the Windows command fallback so a missing directory
      # is not mistaken for a missing executable. Process still checks it at spawn
      # time in case it changes after this check.
      private def with_execution_context(command : String, cwd : String?, &)
        if cwd && !Dir.exists?(cwd)
          raise Lune::Error.new("shell_invalid_cwd", "Working directory does not exist or is not a directory: #{cwd}")
        end
        yield
      rescue ex : File::NotFoundError
        raise Lune::Error.new("shell_command_not_found", "Could not start #{command.inspect}: #{ex.message}")
      rescue ex : IO::Error
        raise Lune::Error.new("shell_spawn_failed", "Could not run #{command.inspect} in #{cwd || Dir.current}: #{ex.message}")
      end

      private def spawn_proc(app : Lune::App, cmd : String, argv : Array(String), cwd : String?, env : Hash(String, String?)?) : String
        pid = Random.new.hex(8)
        process = Shell.with_win32_cmd_fallback(cmd, argv) do |c, a|
          Process.new(c, args: a, chdir: cwd, env: env, input: :pipe, output: :pipe, error: :pipe)
        end
        @mu.synchronize do
          @processes[pid] = process
          @stdins[pid] = process.input
        end

        stdout_io = process.output
        stderr_io = process.error
        done = ::Channel(Nil).new(2)

        app.async("shell-#{pid}-out") do
          while line = stdout_io.gets
            app.stream.send("shell:#{pid}:stdout", {"line" => line})
          end
          done.send(nil)
        end

        app.async("shell-#{pid}-err") do
          while line = stderr_io.gets
            app.stream.send("shell:#{pid}:stderr", {"line" => line})
          end
          done.send(nil)
        end

        app.async("shell-#{pid}-wait") do
          2.times { done.receive }
          status = process.wait
          @mu.synchronize do
            @processes.delete(pid)
            @stdins.delete(pid).try { |io| io.close rescue nil }
          end
          # exit_code? returns nil for signal-terminated processes (e.g. SIGTERM from kill)
          app.stream.send("shell:#{pid}:exit", {"code" => (status.exit_code? || -1)})
        end

        pid
      end
    end
  end
end
