module LuneCLI
  module Commands
    class Doctor
      def to_command : Argy::Command
        command = Argy::Command.new(
          use: "doctor",
          short: "Check your Lune development environment",
          long: "Verify that Crystal, Node, npm, shards, and frontend dependencies are all present."
        )

        config = LuneCLI::Config.load

        command.on_run do |_cmd, _args|
          unless run(
                   frontend_dir: config.frontend.dir,
                   app_entry: config.app_entry,
                   install_hint: config.frontend.install || DEFAULT_INSTALL_CMD
                 )
            raise Argy::Error.new("doctor found issues")
          end
        end

        command
      end

      def run(frontend_dir : String, app_entry : String, install_hint : String = DEFAULT_INSTALL_CMD, output : IO = STDOUT) : Bool
        checks = [
          check_crystal,
          check_tool("node", ["--version"]),
          check_tool(NPM_CMD, ["--version"], label: "npm"),
          check_shards,
          check_frontend_deps(frontend_dir, install_hint),
          check_app_entry(app_entry),
        ]

        checks.each { |c| print_check(c, output) }
        output.puts
        checks.all?(&.ok)
      end

      private record Check, label : String, ok : Bool, detail : String

      CRYSTAL_MIN = SemanticVersion.parse("1.20.1")

      private def check_crystal : Check
        output = IO::Memory.new
        status = Process.run("crystal", ["--version"], output: output, error: Process::Redirect::Close)
        return Check.new(label: "crystal", ok: false, detail: "not found") unless status.success?

        version_line = output.to_s.lines.first?.try(&.strip) || "unknown"
        version_str = version_line[/Crystal (\d+\.\d+\.\d+)/, 1]?
        return Check.new(label: "crystal", ok: true, detail: version_line) unless version_str

        installed = SemanticVersion.parse(version_str)
        ok = installed >= CRYSTAL_MIN
        detail = ok ? version_line : "#{version_line} — Lune requires >= #{CRYSTAL_MIN} (-Dexecution_context)"
        Check.new(label: "crystal", ok: ok, detail: detail)
      rescue File::NotFoundError
        Check.new(label: "crystal", ok: false, detail: "not found")
      end

      private def check_tool(cmd : String, args : Array(String), label : String = cmd) : Check
        output = IO::Memory.new
        program, run_args = LuneCLI::ProcessSpawn.wrap(cmd, args)
        status = Process.run(program, run_args, output: output, error: Process::Redirect::Close)
        version = output.to_s.lines.first?.try(&.strip) || "unknown"
        Check.new(label: label, ok: status.success?, detail: version)
      rescue File::NotFoundError
        Check.new(label: label, ok: false, detail: "not found")
      end

      private def check_shards : Check
        status = Process.run(
          "shards", ["check"],
          input: Process::Redirect::Close,
          output: Process::Redirect::Close,
          error: Process::Redirect::Close
        )
        Check.new(label: "shards", ok: status.success?, detail: status.success? ? "ok" : "run `shards install`")
      rescue File::NotFoundError
        Check.new(label: "shards", ok: false, detail: "shards not found")
      end

      private def check_frontend_deps(frontend_dir : String, install_hint : String) : Check
        ok = Dir.exists?(File.join(frontend_dir, "node_modules"))
        Check.new(
          label: "frontend deps",
          ok: ok,
          detail: ok ? "ok" : "run `#{install_hint}` in #{frontend_dir}"
        )
      end

      private def check_app_entry(app_entry : String) : Check
        ok = File.file?(app_entry)
        Check.new(
          label: "app entry",
          ok: ok,
          detail: ok ? app_entry : "not found: #{app_entry}"
        )
      end

      private def print_check(c : Check, output : IO) : Nil
        mark = c.ok ? "✓" : "✗"
        output.puts "  #{mark}  #{c.label.ljust(16)} #{c.detail}"
      end
    end
  end
end
