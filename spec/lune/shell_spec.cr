require "../spec_helper"

# Cross-platform spawn helpers: Win32 doesn't have POSIX sleep/echo/cat
# as standalone binaries, so use the Windows equivalents. Tests assert on
# binding behaviour, not which command ran.
{% if flag?(:win32) %}
  SHELL_SPEC_SLEEP_CMD  = "ping"
  SHELL_SPEC_SLEEP_ARGS = ["127.0.0.1", "-n", "5"]
  SHELL_SPEC_ECHO_CMD   = "cmd"
  SHELL_SPEC_ECHO_ARGS  = ["/c", "echo", "hello"]
  SHELL_SPEC_STDIN_CMD  = "cmd"
  SHELL_SPEC_STDIN_ARGS = ["/c", "more"]
{% else %}
  SHELL_SPEC_SLEEP_CMD  = "sleep"
  SHELL_SPEC_SLEEP_ARGS = ["5"]
  SHELL_SPEC_ECHO_CMD   = "echo"
  SHELL_SPEC_ECHO_ARGS  = ["hello"]
  SHELL_SPEC_STDIN_CMD  = "cat"
  SHELL_SPEC_STDIN_ARGS = [] of String
{% end %}

private def shell_spec_json_args(args : Array(String)) : Array(JSON::Any)
  args.map { |a| JSON::Any.new(a) }
end

describe Lune::Capabilities::Shell do
  describe "descriptor" do
    it "has correct id and label" do
      d = Lune::Capabilities::Shell::DESCRIPTOR
      d.id.should eq(:shell)
      d.label.should eq("Shell")
    end

    it "declares stream as a hard dep" do
      Lune::Capabilities::Shell::DESCRIPTOR.deps.should contain(:stream)
    end

    it "is not core" do
      Lune::Capabilities::Shell::DESCRIPTOR.core.should be_false
    end
  end

  describe "name and namespace" do
    it "derives name from descriptor" do
      Lune::Capabilities::Shell.new.name.should eq("shell")
    end

    it "has Shell binding namespace" do
      Lune::Capabilities::Shell.new.binding_namespace.should eq("Shell")
    end
  end

  describe "phase membership" do
    it "includes Bindable" do
      Lune::Capabilities::Shell.new.is_a?(Lune::Capability::Bindable).should be_true
    end

    it "includes Lifecycle" do
      Lune::Capabilities::Shell.new.is_a?(Lune::Capability::Lifecycle).should be_true
    end

    it "does not include WebviewInject" do
      Lune::Capabilities::Shell.new.is_a?(Lune::Capability::WebviewInject).should be_false
    end
  end

  describe "install" do
    it "registers spawn, kill, run, list, write, and close_stdin bindings" do
      cap = Lune::Capabilities::Shell.new
      app = Lune::App.new
      app.install(cap)
      ids = app.bindings.map(&.id)
      ids.should contain("__lune.shell.spawn")
      ids.should contain("__lune.shell.kill")
      ids.should contain("__lune.shell.run")
      ids.should contain("__lune.shell.list")
      ids.should contain("__lune.shell.write")
      ids.should contain("__lune.shell.close_stdin")
    end

    it "list binding returns empty array when no processes are running" do
      cap = Lune::Capabilities::Shell.new
      app = Lune::App.new
      app.install(cap)
      list_b = app.bindings.find { |b| b.id == "__lune.shell.list" }.not_nil!
      result = list_b.callback.call([] of JSON::Any)
      result.as_a.should be_empty
    end

    it "list binding returns pid after spawn" do
      cap = Lune::Capabilities::Shell.new
      app = Lune::App.new
      app.install(cap)
      spawn_b = app.bindings.find { |b| b.id == "__lune.shell.spawn" }.not_nil!
      list_b = app.bindings.find { |b| b.id == "__lune.shell.list" }.not_nil!
      pid = spawn_b.callback.call([JSON::Any.new(SHELL_SPEC_SLEEP_CMD), JSON::Any.new(shell_spec_json_args(SHELL_SPEC_SLEEP_ARGS))]).as_s
      pids = list_b.callback.call([] of JSON::Any).as_a.map(&.as_s)
      pids.should contain(pid)
      # cleanup
      kill_b = app.bindings.find { |b| b.id == "__lune.shell.kill" }.not_nil!
      kill_b.callback.call([JSON::Any.new(pid)])
    end

    it "spawn binding returns a string pid" do
      cap = Lune::Capabilities::Shell.new
      app = Lune::App.new
      app.install(cap)
      spawn_b = app.bindings.find { |b| b.id == "__lune.shell.spawn" }.not_nil!
      result = spawn_b.callback.call([JSON::Any.new(SHELL_SPEC_ECHO_CMD), JSON::Any.new(shell_spec_json_args(SHELL_SPEC_ECHO_ARGS))])
      result.as_s.size.should eq(16) # Random.new.hex(8) → 16 hex chars
    end

    it "kill binding accepts a pid and returns nil" do
      cap = Lune::Capabilities::Shell.new
      app = Lune::App.new
      app.install(cap)
      kill_b = app.bindings.find { |b| b.id == "__lune.shell.kill" }.not_nil!
      # killing a non-existent pid is a no-op
      result = kill_b.callback.call([JSON::Any.new("nonexistent")])
      result.raw.should be_nil
    end

    it "run binding executes a process and returns stdout, stderr, code" do
      cap = Lune::Capabilities::Shell.new
      app = Lune::App.new
      app.install(cap)
      run_b = app.bindings.find { |b| b.id == "__lune.shell.run" }.not_nil!
      result = run_b.callback.call([JSON::Any.new(SHELL_SPEC_ECHO_CMD), JSON::Any.new(shell_spec_json_args(SHELL_SPEC_ECHO_ARGS))])
      result["stdout"].as_s.strip.should eq("hello")
      result["stderr"].as_s.should eq("")
      result["code"].as_i.should eq(0)
    end

    it "write to nonexistent pid is a no-op" do
      cap = Lune::Capabilities::Shell.new
      app = Lune::App.new
      app.install(cap)
      write_b = app.bindings.find { |b| b.id == "__lune.shell.write" }.not_nil!
      result = write_b.callback.call([JSON::Any.new("nonexistent"), JSON::Any.new("hello\n")])
      result.raw.should be_nil
    end

    it "close_stdin to nonexistent pid is a no-op" do
      cap = Lune::Capabilities::Shell.new
      app = Lune::App.new
      app.install(cap)
      close_b = app.bindings.find { |b| b.id == "__lune.shell.close_stdin" }.not_nil!
      result = close_b.callback.call([JSON::Any.new("nonexistent")])
      result.raw.should be_nil
    end

    it "write sends text to a live process stdin" do
      cap = Lune::Capabilities::Shell.new
      app = Lune::App.new
      app.install(cap)
      spawn_b = app.bindings.find { |b| b.id == "__lune.shell.spawn" }.not_nil!
      write_b = app.bindings.find { |b| b.id == "__lune.shell.write" }.not_nil!
      close_b = app.bindings.find { |b| b.id == "__lune.shell.close_stdin" }.not_nil!
      # Stdin-consumer process (cat on POSIX, more on Win32) — test that
      # write + close_stdin doesn't raise. Content isn't asserted here.
      pid = spawn_b.callback.call([JSON::Any.new(SHELL_SPEC_STDIN_CMD), JSON::Any.new(shell_spec_json_args(SHELL_SPEC_STDIN_ARGS))]).as_s
      write_b.callback.call([JSON::Any.new(pid), JSON::Any.new("hello\n")]).raw.should be_nil
      close_b.callback.call([JSON::Any.new(pid)]).raw.should be_nil
    end
  end

  describe "js_helpers" do
    it "exposes listen" do
      Lune::Capabilities::Shell.new.js_helpers.should contain("listen(")
    end

    it "exposes unlisten" do
      Lune::Capabilities::Shell.new.js_helpers.should contain("unlisten(")
    end

    it "uses stOn/stOff from stream bridge" do
      h = Lune::Capabilities::Shell.new.js_helpers
      h.should contain("stOn(")
      h.should contain("stOff(")
    end
  end

  describe "dts_helpers" do
    it "types listen with stdout, stderr, and exit callbacks" do
      h = Lune::Capabilities::Shell.new.dts_helpers
      h.should contain("listen(pid: string")
      h.should contain("stdout?")
      h.should contain("stderr?")
      h.should contain("exit?")
    end

    it "types unlisten" do
      Lune::Capabilities::Shell.new.dts_helpers.should contain("unlisten(pid: string)")
    end

    it "types write and close_stdin via bindings (not duplicated in helpers)" do
      cap = Lune::Capabilities::Shell.new
      app = Lune::App.new
      app.install(cap)
      dts = Lune::Runtime::Generator.generate_runtime_dts(app.bindings, [cap] of Lune::Capability)
      dts.scan(/write\(pid: string/).size.should eq(1)
      dts.scan(/closeStdin\(pid: string/).size.should eq(1)
      cap.dts_helpers.should_not contain("write(pid: string")
      cap.dts_helpers.should_not contain("closeStdin(pid: string")
    end
  end

  describe "registry integration" do
    it "cascade-disables when stream is excluded" do
      r = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigCapabilities.new(only: nil, exclude: ["stream"]))
      resolved.capabilities.map(&.name).should_not contain("shell")
    end

    it "is included in the default resolved set" do
      r = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigCapabilities.new(only: nil, exclude: nil))
      resolved.capabilities.map(&.name).should contain("shell")
    end
  end
end
