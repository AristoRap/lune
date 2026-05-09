module LuneCLI
  class CheckCommand
    def to_command : Argy::Command
      command = Argy::Command.new(
        use: "check",
        short: "Type-check the Lune app",
        long: "Compile-check the configured Lune app without code generation."
      )

      command.on_pre_run do |cmd, _args|
        app_entry = cmd.string_flag("app-entry")
        unless File.file?(app_entry)
          message = "App entry file not found: #{app_entry}"
          Lune.logger.error { message }
          raise Argy::Error.new(message)
        end
      end

      command.on_run do |cmd, _args|
        app_entry = cmd.string_flag("app-entry")
        Lune.logger.info { "Checking #{app_entry}..." }

        if run(app_entry: app_entry)
          Lune.logger.info { "OK" }
        else
          Lune.logger.error { "check failed" }
          raise Argy::Error.new("check failed")
        end
      end

      command
    end

    def run(app_entry : String) : Bool
      Process.run(
        "crystal",
        ["build", app_entry, "-Dpreview_mt", "--no-codegen"],
        input: Process::Redirect::Inherit,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      ).success?
    end
  end
end
