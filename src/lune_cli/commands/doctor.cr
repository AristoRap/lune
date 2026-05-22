module LuneCLI
  module Commands
    class Doctor
      def to_command : Argy::Command
        command = Argy::Command.new(
          use: "doctor",
          short: "Check your Lune development environment",
          long: "Verify that Crystal, Node, npm, shards, and frontend dependencies are all present."
        )
        command.flags.bool("plugins", 'p', false, "Compile + run app entry in inspect mode to list project-side `Lune.use` registrations (slower).")

        config = LuneCLI::Config.load
        runtime_config = Lune::Config.load

        command.on_run do |cmd, _args|
          unless run(
                   config: config,
                   plugins_config: runtime_config.plugins,
                   inspect_plugins: cmd.bool_flag("plugins"),
                 )
            raise Argy::Error.new("doctor found issues")
          end
        end

        command
      end

      def run(
        config : LuneCLI::Config,
        plugins_config : Lune::Config::Plugins = Lune::Config::Plugins.new,
        inspect_plugins : Bool = false,
        output : IO = STDOUT,
      ) : Bool
        install_hint = config.frontend.install || DEFAULT_INSTALL_CMD
        checks = [
          check_crystal,
          check_tool("node", ["--version"]),
          check_tool(NPM_CMD, ["--version"], label: "npm"),
          check_shards,
          check_frontend_deps(config.frontend.dir, install_hint),
          check_app_entry(config.app_entry),
        ]

        checks.each { |c| print_check(c, output) }
        output.puts
        print_plugins_via_inspect(output, config.app_entry, plugins_config) if inspect_plugins && File.file?(config.app_entry)
        checks.all?(&.ok)
      end

      # `-Dlune_inspect` short-circuit emits the registered plugin set
      # framed between these markers; doctor parses the block out of the
      # captured stdout. The compile+run is gated behind `--plugins` so
      # the default doctor stays fast.
      INSPECT_START = "<<<LUNE_PLUGINS"
      INSPECT_END   = "LUNE_PLUGINS>>>"

      # A row is what `print_plugin_rows` knows how to display — id, label,
      # whether the plugin runs on this platform, and whether it's a
      # framework built-in. Built-in vs imported comes straight from the
      # framework's `Plugin#built_in?` (the Crystal module path check), so
      # the inspect-mode subprocess tells us which is which — no
      # subtraction, no guesswork.
      private record PluginRow, id : String, label : String, on_platform : Bool, built_in : Bool

      # Single entry point for `--plugins`: compile + run `app_entry` with
      # `-Dlune_inspect`, parse the framed list, split into built-in /
      # imported by the framework-set `built_in?` flag, and print each
      # section.
      private def print_plugins_via_inspect(output : IO, app_entry : String, config_plugins : Lune::Config::Plugins) : Nil
        output.puts "  inspecting #{app_entry}..."

        captured = IO::Memory.new
        status = Process.run(
          "crystal",
          ["run", app_entry, "-Dpreview_mt", "-Dexecution_context", "-Dlune_inspect"],
          output: captured,
          error: Process::Redirect::Inherit
        )

        unless status.success?
          output.puts "    !  compile failed — fix the build error, then rerun `lune doctor --plugins`."
          output.puts
          return
        end

        rows = parse_inspect_output(captured.to_s).map do |r|
          PluginRow.new(
            id: r[:id],
            label: r[:label],
            on_platform: r[:platforms].includes?(Lune::Plugins::CURRENT_PLATFORM.to_s),
            built_in: r[:built_in],
          )
        end

        builtin, imported = rows.partition(&.built_in)

        output.puts
        output.puts "  built-in:"
        print_plugin_rows(output, builtin, config_plugins)
        output.puts

        output.puts "  imported:"
        if imported.empty?
          output.puts "    (none — add `Lune.use(MyPlugin.new)` to #{app_entry})"
        else
          print_plugin_rows(output, imported, config_plugins)
        end
        output.puts
      end

      # Public alias for specs — keeps the parser exercised without exposing
      # the rest of the class internals.
      def parse_inspect_output_for_spec(stdout : String)
        parse_inspect_output(stdout)
      end

      private def parse_inspect_output(stdout : String) : Array(NamedTuple(id: String, label: String, platforms: Array(String), built_in: Bool))
        rows = [] of NamedTuple(id: String, label: String, platforms: Array(String), built_in: Bool)
        in_block = false
        stdout.each_line do |line|
          line = line.chomp
          if line == INSPECT_START
            in_block = true
            next
          end
          if line == INSPECT_END
            in_block = false
            next
          end
          next unless in_block
          parts = line.split('\t')
          next unless parts.size == 4
          rows << {
            id:        parts[0],
            label:     parts[1],
            platforms: parts[2].split(","),
            built_in:  parts[3] == "true",
          }
        end
        rows
      end

      # ✓ when the plugin id survives the enabled/disabled config (and
      # implicitly: runs on this platform). ✗ otherwise, with a one-word
      # reason inline so the user can tell why.
      private def print_plugin_rows(
        output : IO,
        rows : Array(PluginRow),
        config_plugins : Lune::Config::Plugins,
      ) : Nil
        enabled_ids = enabled_id_set(rows, config_plugins)

        rows.each do |row|
          enabled = enabled_ids.includes?(row.id)
          mark = (enabled && row.on_platform) ? "✓" : "✗"
          reason =
            if !row.on_platform
              " (not on #{Lune::Plugins::CURRENT_PLATFORM})"
            elsif !enabled
              " (disabled in lune.yml)"
            else
              ""
            end
          output.puts "    #{mark}  #{row.id.ljust(22)} #{row.label}#{reason}"
        end
      end

      WILDCARDS = {"*", "all"}

      private def enabled_id_set(
        rows : Array(PluginRow),
        config_plugins : Lune::Config::Plugins,
      ) : Set(String)
        all_ids = rows.map(&.id)

        en = config_plugins.enabled
        active = if en && !en.empty? && !en.any? { |s| WILDCARDS.includes?(s) }
                   all_ids.select { |id| en.includes?(id) }
                 else
                   all_ids.dup
                 end

        if (di = config_plugins.disabled) && !di.empty?
          if di.any? { |s| WILDCARDS.includes?(s) }
            active = [] of String
          else
            active = active.reject { |id| di.includes?(id) }
          end
        end

        active.to_set
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
