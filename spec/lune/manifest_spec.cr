require "../spec_helper"

# Phase 1a parity harness: lune derives a `Vow::Manifest` from its existing
# `Lune::Binding` set. The manifest is the static contract later phases consume
# (interface emission, then dispatch on `Vow::Registry`), so these specs pin it
# to the *current* wire contract: one procedure per binding, named exactly by
# `Binding#id`, with matching arg names/types and return type — and it must
# round-trip through JSON so it can be snapshotted or served for introspection.

# A representative slice of the built-in surface: NamedTuple returns
# (System.environment, Sqlite.run), JSON::Any args (Sqlite.query/exec, Kv.set),
# multi-arg Int returns (Window), and plain Nil returns.
private def full_app : Lune::App
  app = Lune::App.new
  app.install(
    Lune::Plugins::System.new(on_quit: -> { }),
    Lune::Plugins::Window.new,
    Lune::Plugins::Sqlite.new,
    Lune::Plugins::Kv.new,
    Lune::Plugins::Filesystem.new,
    Lune::Plugins::Clipboard.new,
    Lune::Plugins::Dialogs.new,
  )
  app
end

describe "Lune manifest (vow contract)" do
  describe "Lune::Binding#to_vow_descriptor" do
    it "mirrors the binding's id, arg names/types, and return type" do
      b = Lune::Binding.new(
        namespace: "Lune::Plugins::Window",
        method: "set_size",
        args: ["Int32", "Int32"],
        return_type: "Nil",
        internal: true,
        async: false,
        arg_names: ["width", "height"],
      )

      d = b.to_vow_descriptor
      d.name.should eq("Lune.Plugins.Window.setSize")
      d.args.map(&.name).should eq(["width", "height"])
      d.args.map(&.type).should eq(["Int32", "Int32"])
      d.return_type.should eq("Nil")
      d.opts.should be_empty
    end

    it "falls back to positional arg names when none are supplied" do
      b = Lune::Binding.new(
        namespace: "demo",
        method: "greet",
        args: ["String"],
        return_type: "String",
      )
      b.to_vow_descriptor.args.map(&.name).should eq(["arg0"])
    end

    it "produces a no-arg descriptor for a zero-arg binding" do
      b = Lune::Binding.new(
        namespace: "demo",
        method: "ping",
        args: [] of String,
        return_type: "Nil",
      )
      b.to_vow_descriptor.args.should be_empty
    end
  end

  describe "App#manifest" do
    it "emits exactly one procedure per binding" do
      app = full_app
      app.bindings.should_not be_empty
      app.manifest.procedures.size.should eq(app.bindings.size)
    end

    it "names every procedure by the binding's wire id" do
      app = full_app
      app.manifest.procedures.map(&.name).sort.should eq(app.bindings.map(&.id).sort)
    end

    it "captures a known plugin procedure faithfully" do
      app = Lune::App.new
      app.install(Lune::Plugins::Window.new)
      d = app.manifest.procedures.find { |p| p.name == "Lune.Plugins.Window.setSize" }.not_nil!
      d.args.map(&.type).should eq(["Int32", "Int32"])
      d.return_type.should eq("Nil")
    end

    it "round-trips through JSON" do
      app = full_app
      restored = Vow::Manifest.from_json(app.manifest.to_json)
      restored.procedures.map(&.name).sort.should eq(app.manifest.procedures.map(&.name).sort)
    end
  end

  # Phase 3 gate: the full shipped builtin wire contract, resolved exactly as
  # `_build_run` does (every default-enabled plugin). Any change to a
  # procedure's dispatch id, arg keys, arg types, or return type surfaces here
  # as a deliberate diff — so the upcoming dispatch-engine refactor can prove it
  # preserved the contract (or shows precisely what moved).
  describe "builtin wire-contract snapshot" do
    it "pins every shipped procedure's id, arg keys/types, and return type" do
      registry = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      app = Lune::App.new
      registry.validate_resolve_install(Lune::Config::Plugins.new(enabled: nil, disabled: nil), app)

      signatures = app.manifest.procedures.map do |p|
        args = p.args.map { |a| "#{a.name}: #{a.type}#{a.optional ? "?" : ""}" }.join(", ")
        "#{p.name}(#{args}) -> #{p.return_type}"
      end.sort

      # The full macOS contract. Some bindings are compiled out on other
      # platforms (the same gating the runtime-bindings count spec documents):
      # DragOut is darwin-only; Window.startDrag is darwin + win32 (Linux still
      # needs _NET_WM_MOVERESIZE). Drop those entries per platform so the snapshot
      # pins the *shipped* contract on each OS rather than only macOS.
      expected = [
        "Lune.Plugins.Clipboard.read() -> String",
        "Lune.Plugins.Clipboard.readHtml() -> String",
        "Lune.Plugins.Clipboard.readImage() -> String",
        "Lune.Plugins.Clipboard.write(text: String) -> Nil",
        "Lune.Plugins.Clipboard.writeHtml(html: String) -> Nil",
        "Lune.Plugins.Clipboard.writeImage(dataUrl: String) -> Nil",
        "Lune.Plugins.ContextMenu.show(x: Float64, y: Float64, itemsJson: String) -> Nil",
        "Lune.Plugins.Dialogs.messageError(title: String, message: String) -> Nil",
        "Lune.Plugins.Dialogs.messageInfo(title: String, message: String) -> Nil",
        "Lune.Plugins.Dialogs.messageQuestion(title: String, message: String) -> String",
        "Lune.Plugins.Dialogs.messageWarning(title: String, message: String) -> Nil",
        "Lune.Plugins.Dialogs.openDir(prompt: String) -> String",
        "Lune.Plugins.Dialogs.openFile(prompt: String, filters: Array(NamedTuple(name: String, extensions: Array(String)))) -> String",
        "Lune.Plugins.Dialogs.openFiles(prompt: String, filters: Array(NamedTuple(name: String, extensions: Array(String)))) -> Array(String)",
        "Lune.Plugins.Dialogs.saveFile(prompt: String, filename: String, filters: Array(NamedTuple(name: String, extensions: Array(String)))) -> String",
        "Lune.Plugins.DragOut.start(paths: Array(String)) -> Nil",
        "Lune.Plugins.Event.emit(name: String, data: JSON::Any) -> Nil",
        "Lune.Plugins.FileWatch.unwatch(path: String) -> Nil",
        "Lune.Plugins.FileWatch.watch(path: String) -> Nil",
        "Lune.Plugins.Filesystem.appDataDir() -> String",
        "Lune.Plugins.Filesystem.downloadsDir() -> String",
        "Lune.Plugins.Filesystem.homeDir() -> String",
        "Lune.Plugins.Filesystem.tempDir() -> String",
        "Lune.Plugins.Hotkeys.register(accelerator: String) -> Nil",
        "Lune.Plugins.Hotkeys.unregister(accelerator: String) -> Nil",
        "Lune.Plugins.Introspection.manifest() -> Vow::Manifest",
        "Lune.Plugins.Kv.clear() -> Nil",
        "Lune.Plugins.Kv.delete(key: String) -> Nil",
        "Lune.Plugins.Kv.get(key: String) -> JSON::Any",
        "Lune.Plugins.Kv.has(key: String) -> Bool",
        "Lune.Plugins.Kv.keys() -> Array(String)",
        "Lune.Plugins.Kv.set(key: String, value: JSON::Any) -> Nil",
        "Lune.Plugins.Navigation.changed(url: String) -> Nil",
        "Lune.Plugins.Shell.closeStdin(pid: String) -> Nil",
        "Lune.Plugins.Shell.kill(pid: String) -> Nil",
        "Lune.Plugins.Shell.list() -> Array(String)",
        "Lune.Plugins.Shell.run(command: String, args: Array(String)) -> NamedTuple(stdout: String, stderr: String, code: Int32)",
        "Lune.Plugins.Shell.spawn(command: String, args: Array(String)) -> String",
        "Lune.Plugins.Shell.write(pid: String, text: String) -> Nil",
        "Lune.Plugins.Sqlite.close(db: String) -> Nil",
        "Lune.Plugins.Sqlite.exec(db: String, sql: String, params: Array(JSON::Any)) -> ExecResult",
        "Lune.Plugins.Sqlite.open(path: String) -> String",
        "Lune.Plugins.Sqlite.query(db: String, sql: String, params: Array(JSON::Any)) -> Array(Hash(String, JSON::Any))",
        "Lune.Plugins.System.environment() -> NamedTuple(os: OS, arch: String, devtools: Bool)",
        "Lune.Plugins.System.notify(title: String, body: String) -> Nil",
        "Lune.Plugins.System.openUrl(url: String) -> Nil",
        "Lune.Plugins.System.quit() -> Nil",
        "Lune.Plugins.System.screenInfo() -> NamedTuple(width: Int32, height: Int32, scale: Float64)",
        "Lune.Plugins.Tray.hide() -> Nil",
        "Lune.Plugins.Tray.popupMenu() -> Nil",
        "Lune.Plugins.Tray.setIcon(path: String) -> Nil",
        "Lune.Plugins.Tray.setMenu(items: Array(NamedTuple(id: String, label: String))) -> Nil",
        "Lune.Plugins.Tray.show(iconPath: String) -> Nil",
        "Lune.Plugins.Window.center() -> Nil",
        "Lune.Plugins.Window.hide() -> Nil",
        "Lune.Plugins.Window.maximize() -> Nil",
        "Lune.Plugins.Window.minimize() -> Nil",
        "Lune.Plugins.Window.setSize(width: Int32, height: Int32) -> Nil",
        "Lune.Plugins.Window.setTitle(title: String) -> Nil",
        "Lune.Plugins.Window.show() -> Nil",
        "Lune.Plugins.Window.startDrag() -> Nil",
        "Lune.Plugins.Windows.close(id: String) -> Nil",
        "Lune.Plugins.Windows.list() -> Array(String)",
        "Lune.Plugins.Windows.open(opts: Hash(String, JSON::Any)) -> String",
      ]

      case Lune::Plugins::CURRENT_PLATFORM
      when :linux
        expected.reject! { |s| s.starts_with?("Lune.Plugins.DragOut.") || s == "Lune.Plugins.Window.startDrag() -> Nil" }
      when :win32
        expected.reject! { |s| s.starts_with?("Lune.Plugins.DragOut.") }
      end

      signatures.should eq(expected.sort)
    end
  end
end
