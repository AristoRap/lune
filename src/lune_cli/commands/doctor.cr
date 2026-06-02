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
                   output: cmd.stdout,
                 )
            raise Argy::Error.new("doctor found issues")
          end
        end

        command.add_command(api_subcommand(config))
        command
      end

      # `lune doctor api` — introspect the typed RPC contract the app exposes.
      # A subcommand (not a `--api` flag) so it owns its own output contract: the
      # table goes to stdout, and `--json` swaps it for the raw manifest with no
      # environment report, leaving stdout a clean pipeable stream.
      private def api_subcommand(config : LuneCLI::Config) : Argy::Command
        cmd = Argy::Command.new(
          use: "api",
          short: "Introspect the typed RPC contract the app exposes",
          long: "Compile + run the app entry to list every procedure (name, args, return type) and the custom types its signatures reference. Slower than the base checks since it builds the app."
        )
        cmd.flags.bool("json", nil, false, "Print the raw Vow manifest JSON on stdout (no environment report) for piping into tooling.")

        cmd.on_run do |c, _args|
          run_api(
            config: config,
            json: c.bool_flag("json"),
            output: c.stdout,
            err: c.stderr,
          )
        end

        cmd
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

      # Drives `lune doctor api`. In `--json` mode stdout carries only the
      # manifest JSON (diagnostics divert to `err`); otherwise the contract table
      # is rendered with a leading "inspecting…" line.
      def run_api(
        config : LuneCLI::Config,
        json : Bool = false,
        output : IO = STDOUT,
        err : IO = STDERR,
      ) : Bool
        unless File.file?(config.app_entry)
          err.puts "app entry not found: #{config.app_entry}"
          return false
        end

        print_manifest_via_inspect(output, err, config.app_entry, json: json)
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

      # Markers framing the manifest JSON emitted by `-Dlune_inspect_api` (kept
      # in sync with `Lune::INSPECT_MANIFEST_START` / `_END`).
      MANIFEST_START = "<<<LUNE_MANIFEST"
      MANIFEST_END   = "LUNE_MANIFEST>>>"

      # Single entry point for `doctor api`: compile + run `app_entry` with
      # `-Dlune_inspect_api`, lift the framed `Vow::Manifest` JSON out of the
      # captured stdout, and either render the contract table or (with `--json`)
      # print the raw manifest straight through for tooling. Returns whether the
      # contract was successfully introspected.
      private def print_manifest_via_inspect(output : IO, err : IO, app_entry : String, json : Bool) : Bool
        output.puts "  inspecting #{app_entry} (api)..." unless json

        captured = IO::Memory.new
        status = Process.run(
          "crystal",
          ["run", app_entry, "-Dpreview_mt", "-Dexecution_context", "-Dlune_inspect_api"],
          output: captured,
          error: Process::Redirect::Inherit
        )

        # In `--json` mode diagnostics go to the error stream so stdout stays a
        # clean, pipeable JSON stream (empty on failure); otherwise they join the
        # report on the normal output stream.
        diag = json ? err : output

        unless status.success?
          diag.puts "    !  compile failed — fix the build error, then rerun `lune doctor api`."
          diag.puts unless json
          return false
        end

        manifest = parse_manifest_output(captured.to_s)

        if json
          output.puts manifest.to_json
        else
          output.puts
          print_manifest_table(manifest, output)
          output.puts
        end
        true
      rescue ex : ManifestParseError
        diag = json ? err : output
        diag.puts "    !  #{ex.message}"
        diag.puts unless json
        false
      end

      # Public aliases for specs — exercise the parser and the table renderer
      # without driving a full compile.
      def parse_inspect_output_for_spec(stdout : String)
        parse_inspect_output(stdout)
      end

      def parse_manifest_output_for_spec(stdout : String) : Vow::Manifest
        parse_manifest_output(stdout)
      end

      def print_manifest_table_for_spec(manifest : Vow::Manifest, output : IO) : Nil
        print_manifest_table(manifest, output)
      end

      # Raised when `doctor api` output carries no manifest block (typically a
      # runner that didn't reach the inspect short-circuit).
      class ManifestParseError < Exception
      end

      private def parse_manifest_output(stdout : String) : Vow::Manifest
        in_block = false
        json = String.build do |s|
          stdout.each_line do |line|
            chomped = line.chomp
            if chomped == MANIFEST_START
              in_block = true
              next
            end
            if chomped == MANIFEST_END
              in_block = false
              next
            end
            s << chomped << '\n' if in_block
          end
        end

        raise ManifestParseError.new("no manifest block found in app output") if json.blank?
        Vow::Manifest.from_json(json)
      rescue ex : JSON::ParseException
        raise ManifestParseError.new("manifest block is not valid JSON — #{ex.message}")
      end

      # The human contract table: procedures as `name(args) -> return` (with the
      # transport verb tag when it isn't the neutral `post` default), then the
      # custom types — structs as `{ field: Type; … }`, enums as the
      # string-literal union they emit on the wire.
      private def print_manifest_table(manifest : Vow::Manifest, output : IO) : Nil
        procs = manifest.procedures
        output.puts "  procedures (#{procs.size}):"
        if procs.empty?
          output.puts "    (none — no @[Lune::Bind] surface registered)"
        else
          procs.each do |p|
            args = p.args.map { |a| "#{a.name}: #{a.type}#{a.optional ? "?" : ""}" }.join(", ")
            output.puts "    #{p.name}(#{args}) -> #{p.return_type}"
          end
        end

        output.puts
        types = manifest.types
        output.puts "  types (#{types.size}):"
        if types.empty?
          output.puts "    (none)"
        else
          types.each do |t|
            if t.kind == "enum"
              union = t.members.map { |m| m.inspect }.join(" | ")
              output.puts "    #{t.name} = #{union}"
            else
              fields = t.fields.map { |f| "#{f.name}: #{f.type}" }.join("; ")
              output.puts "    #{t.name} { #{fields} }"
            end
          end
        end
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
