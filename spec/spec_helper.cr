require "spec"
require "../src/lune"
require "../src/lune_cli"
require "./support/fake_webview"

class Argy::Command
  def __execute_without_rescue_for_spec(argv : Array(String)) : Nil
    argv = argv[1..] if argv.first? == name
    root = root_command
    root.reset_tree_state!
    root.validate_tree_flag_collisions!
    _execute(argv)
  end
end

Spec.before_each do
  Lune.logger = Lune.default_logger.tap do |logger|
    logger.level = Log::Severity::None
  end
end

def with_tempdir(& : String -> _)
  dir = File.join(Dir.tempdir, "lune_rt_#{Random.new.hex(8)}")
  Dir.mkdir_p(dir)
  begin
    yield dir
  ensure
    FileUtils.rm_rf(dir)
  end
end
