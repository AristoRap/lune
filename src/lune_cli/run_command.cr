module LuneCLI
  class RunCommand
    def to_command : Argy::Command
      command = Argy::Command.new(
        use: "run",
        aliases: ["r"],
        short: "Run the built Lune app",
        long: "Run the previously built Lune app artifact for the configured app entry."
      )

      command.on_pre_run do |cmd, _args|
        app_entry = cmd.string_flag("app-entry")
        if message = validate_paths(app_entry: app_entry)
          Lune.logger.error { message }
          raise Argy::Error.new(message)
        end
      end

      command.on_run do |cmd, _args|
        app_entry = cmd.string_flag("app-entry")
        unless run(app_entry: app_entry)
          Lune.logger.error { "run failed" }
          raise Argy::Error.new("run failed")
        end
      end

      command
    end

    def artifact_path_for(app_entry : String) : String
      BuildCommand.new.output_path_for(app_entry)
    end

    def validate_paths(app_entry : String) : String?
      return "App entry file not found: #{app_entry}" unless File.file?(app_entry)

      artifact_path = artifact_path_for(app_entry)
      {% if flag?(:darwin) %}
        return "Built app not found: #{artifact_path}. Run 'lune build --app-entry #{app_entry}' first." unless Dir.exists?(artifact_path)
      {% else %}
        return "Built app not found: #{artifact_path}. Run 'lune build --app-entry #{app_entry}' first." unless File.file?(artifact_path)
      {% end %}

      nil
    end

    def run_lock_slug(app_entry : String) : String
      abs = File.expand_path(artifact_path_for(app_entry))
      "run-" + Lune::SingleInstance.slug(abs)
    end

    def run(
      app_entry : String,
      lock_dir : String = File.join(Path.home, ".lune")
    ) : Bool
      lock_file = Lune::SingleInstance.acquire(run_lock_slug(app_entry), lock_dir)
      unless lock_file
        Lune.logger.error { "Another instance is already running for #{app_entry}" }
        return false
      end

      artifact_path = artifact_path_for(app_entry)

      {% if flag?(:darwin) %}
        Process.run(
          "open",
          [artifact_path],
          input: Process::Redirect::Inherit,
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit
        ).success?
      {% else %}
        Process.run(
          artifact_path,
          [] of String,
          input: Process::Redirect::Inherit,
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit
        ).success?
      {% end %}
    end
  end
end
