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
end
