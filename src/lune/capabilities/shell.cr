module Lune
  module Capabilities
    class Shell < Lune::Capability
      include Capability::Bindable
      include Capability::Lifecycle

      DESCRIPTOR = Descriptor.new(id: :shell, label: "Shell", deps: [:stream])

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @processes = {} of String => Process
      @mu = Mutex.new

      def install(ctx : BindCtx) : Nil
        app = ctx.app

        ctx.register(Definition.new(
          name: "#{name}.spawn",
          args: ["String", "Array"],
          return_type: "String",
          arg_names: ["command", "args"],
          callback: ->(raw : Array(JSON::Any)) {
            cmd = raw[0].as_s
            argv = raw[1].as_a.map(&.as_s)
            JSON::Any.new(spawn_proc(app, cmd, argv))
          },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.kill",
          args: ["String"],
          return_type: "Nil",
          arg_names: ["pid"],
          callback: ->(raw : Array(JSON::Any)) {
            pid = raw[0].as_s
            @mu.synchronize { @processes[pid]?.try(&.terminate) }
            JSON::Any.new(nil)
          },
        ).binding(binding_namespace))

        # Blocking async binding — collects all output then resolves.
        # Avoids the Stream listener race that occurs when a process exits
        # before the JS .then() callback can register Stream handlers.
        ctx.register(Definition.new(
          name: "#{name}.run",
          args: ["String", "Array"],
          return_type: "Hash",
          arg_names: ["command", "args"],
          async: true,
          ts_return_type: "Promise<{ stdout: string; stderr: string; code: number }>",
          callback: ->(raw : Array(JSON::Any)) {
            cmd = raw[0].as_s
            argv = raw[1].as_a.map(&.as_s)
            out_buf = IO::Memory.new
            err_buf = IO::Memory.new
            status = Process.run(cmd, args: argv, output: out_buf, error: err_buf)
            code = status.exit_code? || -1
            JSON.parse({"stdout" => out_buf.to_s, "stderr" => err_buf.to_s, "code" => code}.to_json)
          },
        ).binding(binding_namespace))
      end

      def shutdown : Nil
        procs = @mu.synchronize { @processes.dup }
        procs.each_value { |pr| pr.terminate rescue nil }
        @mu.synchronize { @processes.clear }
      end

      def js_helpers : String
        bm = BRIDGE_MARKER
        <<-JS
          listen(pid, opts) {
            var b = window.#{bm};
            if (!opts) return;
            if (opts.stdout) b.stOn("shell:" + pid + ":stdout", opts.stdout);
            if (opts.stderr) b.stOn("shell:" + pid + ":stderr", opts.stderr);
            if (opts.exit) {
              var _wrap = function(d) {
                b.stOff("shell:" + pid + ":stdout");
                b.stOff("shell:" + pid + ":stderr");
                b.stOff("shell:" + pid + ":exit");
                opts.exit(d);
              };
              b.stOn("shell:" + pid + ":exit", _wrap);
            }
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
          listen(pid: string, opts: { stdout?: (data: { line: string }) => void; stderr?: (data: { line: string }) => void; exit?: (data: { code: number }) => void }): void;
          unlisten(pid: string): void;
        DTS
      end

      private def spawn_proc(app : Lune::App, cmd : String, argv : Array(String)) : String
        pid = Random.new.hex(8)
        process = Process.new(cmd, args: argv, output: :pipe, error: :pipe)
        @mu.synchronize { @processes[pid] = process }

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
          @mu.synchronize { @processes.delete(pid) }
          # exit_code? returns nil for signal-terminated processes (e.g. SIGTERM from kill)
          app.stream.send("shell:#{pid}:exit", {"code" => (status.exit_code? || -1)})
        end

        pid
      end
    end
  end
end
