require "argy"
require "./lune"
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
