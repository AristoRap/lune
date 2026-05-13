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

# Captures log entries written during a block.
class CaptureBackend < Log::Backend
  getter entries = [] of Log::Entry

  def initialize
    super(:sync)
  end

  def write(entry : Log::Entry)
    @entries << entry
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

# Temporarily swaps Lune.logger for the duration of the block, restoring it on exit.
def with_logger(logger : Log, &)
  original = Lune.logger
  Lune.logger = logger
  begin
    yield
  ensure
    Lune.logger = original
  end
end

# Runs the block inside a blank temp dir (no lune.yml) with Dir.cd applied.
def in_blank_project(& : ->)
  with_tempdir do |dir|
    Dir.cd(dir) { yield }
  end
end

# Runs the block inside a temp dir containing the given lune.yml content, with Dir.cd applied.
def in_project_with(lune_yml : String, & : ->)
  with_tempdir do |dir|
    File.write(File.join(dir, "lune.yml"), lune_yml)
    Dir.cd(dir) { yield }
  end
end
