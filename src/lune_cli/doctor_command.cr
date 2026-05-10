module LuneCLI
  class DoctorCommand
    def to_command : Argy::Command
      command = Argy::Command.new(
        use: "doctor",
        short: "Check your Lune development environment",
        long: "Verify that Crystal, Node, npm, shards, and frontend dependencies are all present."
      )

      command.on_run do |cmd, _args|
        frontend_dir = cmd.string_flag("frontend-dir")
        app_entry    = cmd.string_flag("app-entry")

        unless run(frontend_dir: frontend_dir, app_entry: app_entry)
          raise Argy::Error.new("doctor found issues")
        end
      end

      command
    end

    def run(frontend_dir : String, app_entry : String) : Bool
      checks = [
        check_tool("crystal", ["--version"]),
        check_tool("node",    ["--version"]),
        check_tool(NPM_CMD,   ["--version"], label: "npm"),
        check_shards,
        check_frontend_deps(frontend_dir),
        check_app_entry(app_entry),
      ]

      checks.each { |c| print_check(c) }
      puts
      checks.all?(&.ok)
    end

    private record Check, label : String, ok : Bool, detail : String

    private def check_tool(cmd : String, args : Array(String), label : String = cmd) : Check
      output = IO::Memory.new
      status = Process.run(cmd, args, output: output, error: Process::Redirect::Close)
      version = output.to_s.lines.first?.try(&.strip) || "unknown"
      Check.new(label: label, ok: status.success?, detail: version)
    rescue
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
    rescue
      Check.new(label: "shards", ok: false, detail: "shards not found")
    end

    private def check_frontend_deps(frontend_dir : String) : Check
      ok = Dir.exists?(File.join(frontend_dir, "node_modules"))
      Check.new(
        label: "frontend deps",
        ok: ok,
        detail: ok ? "ok" : "run `npm install` in #{frontend_dir}"
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

    private def print_check(c : Check)
      mark = c.ok ? "✓" : "✗"
      puts "  #{mark}  #{c.label.ljust(16)} #{c.detail}"
    end
  end
end
