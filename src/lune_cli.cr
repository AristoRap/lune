require "argy"
require "./lune"
require "./lune_cli/config"
require "./lune_cli/file_watcher"
require "./lune_cli/build_command"
require "./lune_cli/check_command"
require "./lune_cli/dev_command"
require "./lune_cli/doctor_command"
require "./lune_cli/run_command"
require "./lune_cli/init_command"
require "./lune_cli/version_command"
require "./lune_cli/root"

module LuneCLI
  def self.root_command : Argy::Command
    Root.build
  end

  def self.execute(argv : Array(String) = ARGV.to_a) : Nil
    root_command.execute(argv)
  end

  def self.pregen_runtime_js(frontend_dir : String) : Nil
    Lune::Runtime.write_js([] of String, File.join(frontend_dir, "lunejs"))
  rescue ex
    Lune.logger.warn { "Could not pre-generate Lune runtime JS: #{ex.message}" }
  end
end
