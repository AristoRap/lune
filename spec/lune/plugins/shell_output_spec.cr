require "../../spec_helper"

private def shell_output_app
  app = Lune::App.new
  plugin = Lune::Plugins::Shell.new
  app.install(plugin)
  {app, plugin}
end

private def shell_output_start(plugin, script)
  plugin.spawn(Process.find_executable("node").not_nil!, ["-e", script])
end

private def shell_output_finished(plugin, pid)
  deadline = Time.instant + 10.seconds
  loop do
    result = plugin.snapshot(pid)
    return result unless result.running
    raise "Timed out waiting for Shell completion" if Time.instant > deadline
    sleep 5.milliseconds
  end
end

# Test-only access to the actual pump with an injected failing reader. This
# checks completion notification and pipe closure, not just parser behavior.
class Lune::Plugins::Shell
  def spec_failed_pump(io : IO)
    pid = "injected-read-failure"
    @mu.synchronize { @history[pid] = OutputHistory.new(10, 100) }
    done = Channel(Nil).new(2)
    pump_output(@app, pid, "stdout", io, 100, done)
    select
    when done.receive
    when timeout(1.second)
      raise "Pump did not signal completion (closed=#{io.closed?})"
    end
    select
    when done.receive
      raise "Pump signaled completion twice"
    else
    end
    snapshot(pid)
  end
end

private class ShellFailingReader < IO::Memory
  def read(slice : Bytes) : Int32
    raise IO::Error.new("injected read failure")
  end
end

describe "Shell output recovery" do
  it "recovers immediate output and nonzero completion without a Stream connection" do
    app, plugin = shell_output_app
    begin
      pid = shell_output_start(plugin, "console.log('first'); console.error('error'); process.stdout.write('tail'); process.exitCode = 7;")
      result = shell_output_finished(plugin, pid)
      result.records.select { |r| r.stream == "stdout" }.map(&.line).should eq(["first", "tail"])
      result.records.select { |r| r.stream == "stderr" }.map(&.line).should eq(["error"])
      result.records.map(&.seq).should eq([1_i64, 2_i64, 3_i64])
      result.code.should eq(7)
      result.gap.should be_false
      result.errors.should be_empty
      plugin.list.should be_empty
      plugin.retained.should eq([pid])

      # Independent/repeated attachments cannot consume each other's output.
      plugin.snapshot(pid).to_json.should eq(result.to_json)
      plugin.snapshot(pid, after: 1).records.map(&.seq).should eq([2_i64, 3_i64])
      tail = plugin.snapshot(pid, after: result.cursor)
      tail.records.should be_empty
      tail.running.should be_false
      tail.code.should eq(7)

      wire = JSON.parse(app.registry.dispatch("Lune.Plugins.Shell.snapshot", {pid: pid}.to_json, nil))
      wire["records"].as_a.size.should eq(3)
      wire["cursor"].as_i.should eq(3)
      wire["code"].as_i.should eq(7)
    ensure
      plugin.shutdown
    end
  end

  it "resumes from a cursor while a child runs and after the frontend disconnects" do
    app, plugin = shell_output_app
    begin
      pid = shell_output_start(plugin, "console.log('ready'); process.stdin.once('data', () => { console.error('later'); process.stdout.write('last'); process.stdin.destroy(); });")
      deadline = Time.instant + 10.seconds
      first = plugin.snapshot(pid)
      while first.records.empty?
        raise "No readiness output" if Time.instant > deadline
        sleep 5.milliseconds
        first = plugin.snapshot(pid)
      end
      first.running.should be_true
      first.code.should be_nil
      wire = JSON.parse(app.registry.dispatch("Lune.Plugins.Shell.snapshot", {pid: pid}.to_json, nil))
      wire["code"].raw.should be_nil
      first.records.map(&.line).should eq(["ready"])
      plugin.write(pid, "continue\n")
      shell_output_finished(plugin, pid)
      resumed = plugin.snapshot(pid, first.cursor)
      resumed.records.map(&.line).sort.should eq(["last", "later"])
      resumed.records.all? { |r| r.seq > first.cursor }.should be_true
      resumed.gap.should be_false
      resumed.code.should eq(0)
    ensure
      plugin.shutdown
    end
  end

  it "drains more than pipe capacity on both streams and retains final partial lines" do
    _, plugin = shell_output_app
    plugin.config.output_records = 10_000
    plugin.config.output_bytes = 2 * 1024 * 1024
    begin
      pid = shell_output_start(plugin, "const fs = require('fs'); for (let i=0; i<3000; i++) { fs.writeSync(1, 'o'.repeat(128)+'\\n'); fs.writeSync(2, 'e'.repeat(128)+'\\n'); } fs.writeSync(1, 'out-tail'); fs.writeSync(2, 'err-tail');")
      result = shell_output_finished(plugin, pid)
      {"stdout" => {"o", "out-tail"}, "stderr" => {"e", "err-tail"}}.each do |stream, expected|
        records = result.records.select { |r| r.stream == stream }
        records.size.should eq(3001)
        records[0...3000].all? { |r| r.line == expected[0] * 128 }.should be_true
        records.last.line.should eq(expected[1])
      end
      result.gap.should be_false
      result.code.should eq(0)
    ensure
      plugin.shutdown
    end
  end

  it "keeps draining and completes when live delivery raises" do
    app, plugin = shell_output_app
    app.stream.sender = ->(_name : String, _data : String) { raise IO::Error.new("disconnected") }
    begin
      pid = shell_output_start(plugin, "console.log('one'); console.log('two'); console.error('err');")
      result = shell_output_finished(plugin, pid)
      result.records.map(&.line).sort.should eq(["err", "one", "two"])
      result.errors.should be_empty
      result.code.should eq(0)
      plugin.list.should be_empty
    ensure
      plugin.shutdown
    end
  end

  it "signals pump completion exactly once and records a read failure" do
    _, plugin = shell_output_app
    io = ShellFailingReader.new
    result = plugin.spec_failed_pump(io)
    io.closed?.should be_true
    result.errors.should eq(["stdout: injected read failure"])
  end

  it "reports eviction gaps and truncation through the bound snapshot API" do
    app, plugin = shell_output_app
    plugin.config.output_records = 2
    plugin.config.output_bytes = 12
    plugin.config.line_bytes = 8
    begin
      pid = shell_output_start(plugin, "process.stdout.write('old\\n' + 'x'.repeat(1000000) + '\\nlast\\n');")
      result = shell_output_finished(plugin, pid)
      result.records.map(&.line).should eq(["xxxxxxxx", "last"])
      result.records.map(&.truncated).should eq([true, false])
      result.gap.should be_true
      result.cursor.should eq(3)
      wire = JSON.parse(app.registry.dispatch("Lune.Plugins.Shell.snapshot", {pid: pid, after: 1}.to_json, nil))
      wire["gap"].as_bool.should be_false
      wire["records"][0]["truncated"].as_bool.should be_true
    ensure
      plugin.shutdown
    end
  end

  it "evicts the oldest completed process, protects running ones, and supports explicit cleanup" do
    _, plugin = shell_output_app
    plugin.config.completed_processes = 1
    begin
      active = shell_output_start(plugin, "process.stdin.resume();")
      first = shell_output_start(plugin, "console.log('first')")
      shell_output_finished(plugin, first)
      second = shell_output_start(plugin, "console.log('second')")
      shell_output_finished(plugin, second)
      plugin.retained.sort.should eq([active, second].sort)
      expect_raises(Lune::Error) { plugin.snapshot(first) }.code.should eq("shell_process_not_found")
      expect_raises(Lune::Error) { plugin.forget(active) }.code.should eq("shell_process_running")
      plugin.forget(second)
      plugin.forget(second)
      plugin.retained.should eq([active])
      expect_raises(Lune::Error) { plugin.snapshot(second) }.code.should eq("shell_process_not_found")
    ensure
      plugin.shutdown
    end
  end

  it "rejects unknown process IDs and invalid cursors without silently resetting them" do
    _, plugin = shell_output_app
    begin
      pid = shell_output_start(plugin, "console.log('done')")
      shell_output_finished(plugin, pid)
      [-1_i64, 2_i64].each do |after|
        expect_raises(Lune::Error) { plugin.snapshot(pid, after) }.code.should eq("shell_invalid_cursor")
      end
      _, restarted = shell_output_app
      expect_raises(Lune::Error) { restarted.snapshot(pid, 1) }.code.should eq("shell_process_not_found")
      plugin.config.output_bytes = 0
      expect_raises(Lune::Error) { shell_output_start(plugin, "") }.code.should eq("shell_invalid_limits")
      plugin.list.should be_empty
    ensure
      plugin.shutdown
    end
  end

  it "emits complete snapshot and nested record declarations" do
    app, plugin = shell_output_app
    known = Lune::Generator.known_types(app.plugin_types)
    dts = Lune::Generator.generate_runtime_dts(app.bindings, [plugin] of Lune::Plugin, known: known, types: app.plugin_types)
    dts.should contain("snapshot(args: { pid: string; after?: number })")
    dts.should contain("cursor: number")
    dts.should contain("gap: boolean")
    dts.should contain("code: number | null")
    dts.should contain("truncated: boolean")
    dts.should contain("seq: number")
    dts.should contain("retained(args?: {}): Promise<string[]>")
    dts.should contain("forget(args: { pid: string }): Promise<void>")
  end
end

describe Lune::Plugins::Shell::OutputHistory do
  it "bounds both bytes and records, including empty lines and multibyte text" do
    history = Lune::Plugins::Shell::OutputHistory.new(2, 5)
    history.append("stdout", "éé", false)
    history.append("stdout", "ab", false)
    result = history.snapshot("p", 0)
    result.records.map(&.line).should eq(["ab"])
    result.gap.should be_true
    3.times { history.append("stdout", "", false) }
    history.snapshot("p", 0).records.map(&.seq).should eq([4_i64, 5_i64])
    history.append("stdout", "too large", false)
    result = history.snapshot("p", 0)
    result.records.should be_empty
    result.gap.should be_true
    result.cursor.should eq(6)
    history.snapshot("p", 6).gap.should be_false
  end
end

describe Lune::Plugins::Shell::OutputReader do
  it "preserves line semantics, multibyte boundaries and final partial text" do
    text = "a" * 8191 + "😀\r\n\nlast é"
    lines = [] of {String, Bool}
    Lune::Plugins::Shell::OutputReader.each_line(IO::Memory.new(text), 16384) { |line, truncated| lines << {line, truncated} }
    lines.should eq([{"a" * 8191 + "😀", false}, {"", false}, {"last é", false}])
  end

  it "replaces invalid UTF-8 and marks a truncated multibyte prefix" do
    lines = [] of {String, Bool}
    Lune::Plugins::Shell::OutputReader.each_line(IO::Memory.new(Bytes[255, 10]), 8) { |line, truncated| lines << {line, truncated} }
    lines.should eq([{"�", false}])
    lines.clear
    Lune::Plugins::Shell::OutputReader.each_line(IO::Memory.new("😀\nnext"), 3) { |line, truncated| lines << {line, truncated} }
    lines[0][0].valid_encoding?.should be_true
    lines[0][1].should be_true
    lines[1].should eq({"nex", true})
  end
end
