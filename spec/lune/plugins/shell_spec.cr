require "../../spec_helper"

# Cross-platform spawn helpers. Echo and the stdin-consumer are cmd
# builtins on Win32 — the Shell plugin's `cmd /c` fallback handles
# that transparently, so spec callers can use POSIX-style names on every
# platform. Sleep still needs a Win32-equivalent because `sleep.exe`
# isn't a standard install.
{% if flag?(:win32) %}
  SHELL_SPEC_SLEEP_CMD  = "ping"
  SHELL_SPEC_SLEEP_ARGS = ["127.0.0.1", "-n", "5"]
  SHELL_SPEC_STDIN_CMD  = "more"
  SHELL_SPEC_STDIN_ARGS = [] of String
{% else %}
  SHELL_SPEC_SLEEP_CMD  = "sleep"
  SHELL_SPEC_SLEEP_ARGS = ["5"]
  SHELL_SPEC_STDIN_CMD  = "cat"
  SHELL_SPEC_STDIN_ARGS = [] of String
{% end %}
SHELL_SPEC_ECHO_CMD  = "echo"
SHELL_SPEC_ECHO_ARGS = ["hello"]

private def shell_spec_json_args(args : Array(String)) : Array(JSON::Any)
  args.map { |a| JSON::Any.new(a) }
end

describe Lune::Plugins::Shell do
  describe "descriptor" do
    it "has correct id and label" do
      d = Lune::Plugins::Shell::DESCRIPTOR
      d.id.should eq(:shell)
      d.label.should eq("Shell")
    end

    it "declares stream as a hard dep" do
      Lune::Plugins::Shell::DESCRIPTOR.deps.should contain(:stream)
    end

    it "is not core" do
      Lune::Plugins::Shell::DESCRIPTOR.core.should be_false
    end
  end

  describe "name and namespace" do
    it "derives name from descriptor" do
      Lune::Plugins::Shell.new.name.should eq("shell")
    end

    it "has Shell binding namespace" do
      Lune::Plugins::Shell.new.binding_namespace.should eq("Lune::Plugins::Shell")
    end
  end

  describe "phase membership" do
    it "includes Bindable" do
      Lune::Plugins::Shell.new.is_a?(Lune::Bindable).should be_true
    end

    it "includes Lifecycle" do
      Lune::Plugins::Shell.new.is_a?(Lune::Plugin::Lifecycle).should be_true
    end

    it "does not include WebviewInject" do
      Lune::Plugins::Shell.new.is_a?(Lune::Plugin::WebviewInject).should be_false
    end
  end

  describe "install" do
    it "registers spawn, kill, run, list, write, and close_stdin bindings" do
      plugin = Lune::Plugins::Shell.new
      app = Lune::App.new
      app.install(plugin)
      ids = app.bindings.map(&.id)
      ids.should contain("Lune.Plugins.Shell.spawn")
      ids.should contain("Lune.Plugins.Shell.kill")
      ids.should contain("Lune.Plugins.Shell.run")
      ids.should contain("Lune.Plugins.Shell.list")
      ids.should contain("Lune.Plugins.Shell.write")
      ids.should contain("Lune.Plugins.Shell.closeStdin")
    end

    it "list binding returns empty array when no processes are running" do
      plugin = Lune::Plugins::Shell.new
      app = Lune::App.new
      app.install(plugin)
      list_b = app.bindings.find { |b| b.id == "Lune.Plugins.Shell.list" }.not_nil!
      result = JSON.parse(app.registry.dispatch(list_b.id, ({} of String => JSON::Any).to_json, nil))
      result.as_a.should be_empty
    end

    it "list binding returns pid after spawn" do
      plugin = Lune::Plugins::Shell.new
      app = Lune::App.new
      app.install(plugin)
      spawn_b = app.bindings.find { |b| b.id == "Lune.Plugins.Shell.spawn" }.not_nil!
      list_b = app.bindings.find { |b| b.id == "Lune.Plugins.Shell.list" }.not_nil!
      pid = JSON.parse(app.registry.dispatch(spawn_b.id, ({"command" => JSON::Any.new(SHELL_SPEC_SLEEP_CMD), "args" => JSON::Any.new(shell_spec_json_args(SHELL_SPEC_SLEEP_ARGS))}).to_json, nil)).as_s
      pids = JSON.parse(app.registry.dispatch(list_b.id, ({} of String => JSON::Any).to_json, nil)).as_a.map(&.as_s)
      pids.should contain(pid)
      # cleanup
      kill_b = app.bindings.find { |b| b.id == "Lune.Plugins.Shell.kill" }.not_nil!
      JSON.parse(app.registry.dispatch(kill_b.id, ({"pid" => JSON::Any.new(pid)}).to_json, nil))
    end

    it "spawn binding returns a string pid" do
      plugin = Lune::Plugins::Shell.new
      app = Lune::App.new
      app.install(plugin)
      spawn_b = app.bindings.find { |b| b.id == "Lune.Plugins.Shell.spawn" }.not_nil!
      result = JSON.parse(app.registry.dispatch(spawn_b.id, ({"command" => JSON::Any.new(SHELL_SPEC_ECHO_CMD), "args" => JSON::Any.new(shell_spec_json_args(SHELL_SPEC_ECHO_ARGS))}).to_json, nil))
      result.as_s.size.should eq(16) # Random.new.hex(8) → 16 hex chars
    end

    it "kill binding accepts a pid and returns nil" do
      plugin = Lune::Plugins::Shell.new
      app = Lune::App.new
      app.install(plugin)
      kill_b = app.bindings.find { |b| b.id == "Lune.Plugins.Shell.kill" }.not_nil!
      # killing a non-existent pid does nothing
      result = JSON.parse(app.registry.dispatch(kill_b.id, ({"pid" => JSON::Any.new("nonexistent")}).to_json, nil))
      result.raw.should be_nil
    end

    it "run binding executes a process and returns stdout, stderr, code" do
      plugin = Lune::Plugins::Shell.new
      app = Lune::App.new
      app.install(plugin)
      run_b = app.bindings.find { |b| b.id == "Lune.Plugins.Shell.run" }.not_nil!
      result = JSON.parse(app.registry.dispatch(run_b.id, ({"command" => JSON::Any.new(SHELL_SPEC_ECHO_CMD), "args" => JSON::Any.new(shell_spec_json_args(SHELL_SPEC_ECHO_ARGS))}).to_json, nil))
      result["stdout"].as_s.strip.should eq("hello")
      result["stderr"].as_s.should eq("")
      result["code"].as_i.should eq(0)
    end

    it "write to nonexistent pid does nothing" do
      plugin = Lune::Plugins::Shell.new
      app = Lune::App.new
      app.install(plugin)
      write_b = app.bindings.find { |b| b.id == "Lune.Plugins.Shell.write" }.not_nil!
      result = JSON.parse(app.registry.dispatch(write_b.id, ({"pid" => JSON::Any.new("nonexistent"), "text" => JSON::Any.new("hello\n")}).to_json, nil))
      result.raw.should be_nil
    end

    it "close_stdin to nonexistent pid does nothing" do
      plugin = Lune::Plugins::Shell.new
      app = Lune::App.new
      app.install(plugin)
      close_b = app.bindings.find { |b| b.id == "Lune.Plugins.Shell.closeStdin" }.not_nil!
      result = JSON.parse(app.registry.dispatch(close_b.id, ({"pid" => JSON::Any.new("nonexistent")}).to_json, nil))
      result.raw.should be_nil
    end

    it "write sends text to a live process stdin" do
      plugin = Lune::Plugins::Shell.new
      app = Lune::App.new
      app.install(plugin)
      spawn_b = app.bindings.find { |b| b.id == "Lune.Plugins.Shell.spawn" }.not_nil!
      write_b = app.bindings.find { |b| b.id == "Lune.Plugins.Shell.write" }.not_nil!
      close_b = app.bindings.find { |b| b.id == "Lune.Plugins.Shell.closeStdin" }.not_nil!
      # Stdin-consumer process (cat on POSIX, more on Win32) — test that
      # write + close_stdin doesn't raise. Content isn't asserted here.
      pid = JSON.parse(app.registry.dispatch(spawn_b.id, ({"command" => JSON::Any.new(SHELL_SPEC_STDIN_CMD), "args" => JSON::Any.new(shell_spec_json_args(SHELL_SPEC_STDIN_ARGS))}).to_json, nil)).as_s
      JSON.parse(app.registry.dispatch(write_b.id, ({"pid" => JSON::Any.new(pid), "text" => JSON::Any.new("hello\n")}).to_json, nil)).raw.should be_nil
      JSON.parse(app.registry.dispatch(close_b.id, ({"pid" => JSON::Any.new(pid)}).to_json, nil)).raw.should be_nil
    end
  end

  describe "js_helpers" do
    it "exposes listen" do
      Lune::Plugins::Shell.new.js_helpers.should contain("listen(")
    end

    it "exposes unlisten" do
      Lune::Plugins::Shell.new.js_helpers.should contain("unlisten(")
    end

    it "uses stOn/stOff from stream bridge" do
      h = Lune::Plugins::Shell.new.js_helpers
      h.should contain("stOn(")
      h.should contain("stOff(")
    end
  end

  describe "dts_helpers" do
    it "types listen with stdout, stderr, and exit callbacks" do
      h = Lune::Plugins::Shell.new.dts_helpers
      h.should contain("listen(pid: string")
      h.should contain("stdout?")
      h.should contain("stderr?")
      h.should contain("exit?")
    end

    it "types unlisten" do
      Lune::Plugins::Shell.new.dts_helpers.should contain("unlisten(pid: string)")
    end

    it "types write and close_stdin via bindings (not duplicated in helpers)" do
      plugin = Lune::Plugins::Shell.new
      app = Lune::App.new
      app.install(plugin)
      dts = Lune::Generator.generate_runtime_dts(app.bindings, [plugin] of Lune::Plugin)
      dts.scan(/write\(args: \{ pid: string/).size.should eq(1)
      dts.scan(/closeStdin\(args: \{ pid: string/).size.should eq(1)
      plugin.dts_helpers.should_not contain("write(args: { pid: string")
      plugin.dts_helpers.should_not contain("closeStdin(args: { pid: string")
    end
  end

  describe ".with_win32_cmd_fallback" do
    it "yields cmd + argv as-is when the block succeeds" do
      calls = [] of {String, Array(String)}
      result = Lune::Plugins::Shell.with_win32_cmd_fallback("git", ["status"]) do |c, a|
        calls << {c, a}
        :ok
      end
      result.should eq(:ok)
      calls.should eq([{"git", ["status"]}])
    end

    {% if flag?(:win32) %}
      it "retries with cmd /c on Win32 when the block raises File::NotFoundError" do
        calls = [] of {String, Array(String)}
        result = Lune::Plugins::Shell.with_win32_cmd_fallback("echo", ["hi"]) do |c, a|
          calls << {c, a}
          raise File::NotFoundError.new("no echo.exe", file: c) if calls.size == 1
          :retried
        end
        result.should eq(:retried)
        calls.should eq([{"echo", ["hi"]}, {"cmd", ["/c", "echo", "hi"]}])
      end
    {% else %}
      it "re-raises File::NotFoundError on non-Win32" do
        expect_raises(File::NotFoundError) do
          Lune::Plugins::Shell.with_win32_cmd_fallback("nope", [] of String) do |_c, _a|
            raise File::NotFoundError.new("missing", file: "nope")
          end
        end
      end
    {% end %}
  end

  describe "registry integration" do
    it "cascade-disables when stream is excluded" do
      r = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::Config::Plugins.new(enabled: nil, disabled: ["stream"]))
      resolved.plugins.map(&.name).should_not contain("shell")
    end

    it "is included in the default resolved set" do
      r = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::Config::Plugins.new(enabled: nil, disabled: nil))
      resolved.plugins.map(&.name).should contain("shell")
    end
  end

  describe "runtime.d.ts signatures" do
    it "emits list() as Promise<string[]>" do
      plugin = Lune::Plugins::Shell.new
      app = Lune::App.new
      app.install(plugin)
      dts = Lune::Generator.generate_runtime_dts(app.bindings, [plugin] of Lune::Plugin)
      dts.should contain("list(args?: {}): Promise<string[]>")
    end
  end
end
