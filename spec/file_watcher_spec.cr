require "spec"
require "file_utils"
require "../src/lune_cli/file_watcher"

private def with_tempdir(& : String -> _)
  dir = File.join(Dir.tempdir, "lune_fw_#{Random.new.hex(8)}")
  Dir.mkdir_p(dir)
  begin
    yield dir
  ensure
    FileUtils.rm_rf(dir)
  end
end

describe LuneCLI::FileWatcher do
  describe "#collect_mtimes" do
    it "returns an empty hash when the directory has no .cr files" do
      with_tempdir do |dir|
        LuneCLI::FileWatcher.new.collect_mtimes(dir).should be_empty
      end
    end

    it "returns the modification time for each .cr file" do
      with_tempdir do |dir|
        File.write(File.join(dir, "foo.cr"), "")
        File.write(File.join(dir, "bar.cr"), "")
        mtimes = LuneCLI::FileWatcher.new.collect_mtimes(dir)
        mtimes.size.should eq(2)
        mtimes.keys.should contain(File.join(dir, "foo.cr"))
        mtimes.keys.should contain(File.join(dir, "bar.cr"))
      end
    end

    it "ignores non-.cr files" do
      with_tempdir do |dir|
        File.write(File.join(dir, "foo.cr"), "")
        File.write(File.join(dir, "bar.js"), "")
        File.write(File.join(dir, "README.md"), "")
        mtimes = LuneCLI::FileWatcher.new.collect_mtimes(dir)
        mtimes.size.should eq(1)
      end
    end

    it "finds .cr files in subdirectories" do
      with_tempdir do |dir|
        sub = File.join(dir, "sub")
        Dir.mkdir_p(sub)
        File.write(File.join(dir, "top.cr"), "")
        File.write(File.join(sub, "nested.cr"), "")
        mtimes = LuneCLI::FileWatcher.new.collect_mtimes(dir)
        mtimes.size.should eq(2)
      end
    end
  end

  describe "#changed?" do
    it "returns false for identical snapshots" do
      now = Time.utc
      snap = {"a.cr" => now, "b.cr" => now}
      LuneCLI::FileWatcher.new.changed?(snap, snap).should be_false
    end

    it "returns true when a file's mtime changes" do
      now = Time.utc
      before = {"a.cr" => now}
      after = {"a.cr" => now + 1.second}
      LuneCLI::FileWatcher.new.changed?(before, after).should be_true
    end

    it "returns true when a new file is added" do
      now = Time.utc
      before = {"a.cr" => now}
      after = {"a.cr" => now, "b.cr" => now}
      LuneCLI::FileWatcher.new.changed?(before, after).should be_true
    end

    it "returns true when a file is removed" do
      now = Time.utc
      before = {"a.cr" => now, "b.cr" => now}
      after = {"a.cr" => now}
      LuneCLI::FileWatcher.new.changed?(before, after).should be_true
    end
  end
end
