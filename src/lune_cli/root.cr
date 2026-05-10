module LuneCLI
  {% if flag?(:win32) %}
    NPM_CMD = "npm.cmd"
  {% else %}
    NPM_CMD = "npm"
  {% end %}

  module Root
    DEFAULT_FRONTEND_DIR = "frontend"
    DEFAULT_APP_ENTRY    = "src/main.cr"

    def self.build : Argy::Command
      root = Argy::Command.new(
        use: "lune",
        short: "Lune command-line interface",
        long: "CLI for running and validating Lune apps."
      )

      root.persistent_flags.bool("debug", nil, false, "enable debug logging")
      root.persistent_flags.string("frontend-dir", nil, DEFAULT_FRONTEND_DIR, "frontend directory")
      root.persistent_flags.string("app-entry", nil, DEFAULT_APP_ENTRY, "Crystal app entry file")

      root.on_persistent_pre_run do |cmd, _args|
        if cmd.bool_flag("debug")
          Lune.enable_debug_logging
        else
          Lune.enable_standard_logging
        end
      end

      root.add_command(
        BuildCommand.new.to_command,
        CheckCommand.new.to_command,
        DevCommand.new.to_command,
        DoctorCommand.new.to_command,
        RunCommand.new.to_command,
        InitCommand.new.to_command,
        VersionCommand.new.to_command
      )
      root
    end
  end
end
