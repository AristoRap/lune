require "./constants"
require "./config"
require "./generator"
require "./commands/build"
require "./commands/check"
require "./commands/dev"
require "./commands/dev_error"
require "./commands/dist"
require "./commands/doctor"
require "./commands/run"
require "./commands/init"
require "./commands/version"

module LuneCLI
  module Root
    def self.build : Argy::Command
      root = Argy::Command.new(
        use: "lune",
        short: "Lune command-line interface",
        long: "CLI for running and validating Lune apps."
      )

      root.persistent_flags.bool("debug", nil, false, "enable debug logging")

      root.on_persistent_pre_run do |cmd, _args|
        if cmd.bool_flag("debug")
          Lune.enable_debug_logging
        else
          Lune.enable_standard_logging
        end
      end

      root.add_command(
        Commands::Build.new.to_command,
        Commands::Check.new.to_command,
        Commands::Dev.new.to_command,
        Commands::DevError.new.to_command,
        Commands::Dist.new.to_command,
        Commands::Doctor.new.to_command,
        Commands::Run.new.to_command,
        Commands::Init.new.to_command,
        Commands::Version.new.to_command
      )
      root
    end
  end
end
