require "../spec_helper"
require "file_utils"

private def runtime_app
  app = Lune::App.new
  Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new).all.each { |plugin| app.install(plugin) }
  app
end

private def runtime_bindings
  runtime_app.bindings.select(&.internal?)
end

private def event_plugins
  [Lune::Plugins::Event.new] of Lune::Plugin
end

private def drag_out_plugins
  [Lune::Plugins::DragOut.new] of Lune::Plugin
end

private def drag_out_setup
  plugin = Lune::Plugins::DragOut.new
  app = Lune::App.new
  app.install(plugin)
  {app.bindings, [plugin] of Lune::Plugin}
end

describe Lune::Generator do
  it "generates runtime transport code" do
    js = Lune::Generator.generate_runtime_js([] of Lune::Binding)

    js.includes?("__lune").should be_true
    js.includes?("export const __lune").should be_true
  end

  it "exports LuneError class that extends Error" do
    js = Lune::Generator.generate_runtime_js([] of Lune::Binding)

    js.includes?("export class LuneError extends Error").should be_true
    js.includes?("this.name = \"LuneError\"").should be_true
    js.includes?("this.code = code").should be_true
  end

  it "wraps __lune.call to convert plain error envelopes to LuneError instances" do
    js = Lune::Generator.generate_runtime_js([] of Lune::Binding)

    js.includes?(".catch(").should be_true
    js.includes?("new LuneError(").should be_true
  end

  it "declares LuneError as a class in runtime.d.ts" do
    dts = Lune::Generator.generate_runtime_dts([] of Lune::Binding)

    dts.includes?("export declare class LuneError extends Error").should be_true
    dts.includes?("readonly code: string").should be_true
  end

  it "carries a hint on LuneError (runtime + d.ts)" do
    js = Lune::Generator.generate_runtime_js([] of Lune::Binding)
    js.includes?("this.hint = hint").should be_true

    dts = Lune::Generator.generate_runtime_dts([] of Lune::Binding)
    dts.includes?("readonly hint: string | null").should be_true
  end

  it "exports Event namespace with on, once, off helpers" do
    js = Lune::Generator.generate_runtime_js([] of Lune::Binding, event_plugins)

    js.includes?("export const Lune").should be_true
    js.includes?("Event:").should be_true
    js.includes?("on(name, cb)").should be_true
    js.includes?("once(name, cb)").should be_true
    js.includes?("off(name, cb)").should be_true
    js.includes?("window.__lune.on").should be_true
    js.includes?("window.__lune.off").should be_true
  end

  it "exports emit as a regular @[Bind] method on Event" do
    # emit moved from js_helpers into a real binding (Event.emit). Plugin
    # bindings are passed explicitly to the generator alongside the plugin.
    event = Lune::Plugins::Event.new
    app = Lune::App.new
    app.install(event)
    js = Lune::Generator.generate_runtime_js(app.bindings.select(&.internal?), event_plugins)

    js.includes?("emit(args)").should be_true
    js.includes?(%("Lune.Plugins.Event.emit")).should be_true
  end

  it "declares emit in runtime.d.ts" do
    event = Lune::Plugins::Event.new
    app = Lune::App.new
    app.install(event)
    dts = Lune::Generator.generate_runtime_dts(app.bindings.select(&.internal?), event_plugins)

    dts.includes?("emit(args: { name: string; data: unknown })").should be_true
  end

  it "exports System namespace with quit, openUrl, environment" do
    js = Lune::Generator.generate_runtime_js(runtime_bindings)

    js.includes?("export const Lune").should be_true
    js.includes?("System:").should be_true
    js.includes?("quit(args = {})").should be_true
    js.includes?("openUrl(args)").should be_true
    js.includes?("environment(args = {})").should be_true
    js.includes?("Lune.Plugins.System.quit").should be_true
    js.includes?("Lune.Plugins.System.openUrl").should be_true
    js.includes?("Lune.Plugins.System.environment").should be_true
  end

  it "generates runtime.d.ts with typed namespace interfaces" do
    app = runtime_app
    known = Lune::Generator.known_types(app.manifest.types)
    dts = Lune::Generator.generate_runtime_dts(app.bindings.select(&.internal?), event_plugins, known: known, types: app.plugin_types)

    dts.includes?("export declare const Lune").should be_true
    dts.includes?("System: {").should be_true
    dts.includes?("Event: {").should be_true
    dts.includes?("quit(args?: {})").should be_true
    dts.includes?("openUrl(args:").should be_true
    dts.includes?("environment(args?: {})").should be_true
    dts.includes?("on(name: string").should be_true
    dts.includes?("once(name: string").should be_true
    dts.includes?("off(name: string").should be_true
  end

  it "inlines structural shapes and emits an enum as a string-union type alias" do
    app = runtime_app
    known = Lune::Generator.known_types(app.manifest.types)
    dts = Lune::Generator.generate_runtime_dts(app.bindings.select(&.internal?), event_plugins, known: known, types: app.plugin_types)

    # No named-type carryovers in the d.ts header — every struct shape is either
    # derived from the Crystal type or inlined into the binding's ts_return_type.
    dts.includes?("LuneEnvironment").should be_false
    dts.includes?("ScreenInfo").should be_false
    dts.includes?("TrayMenuItem").should be_false
    dts.includes?("ContextMenuItem").should be_false

    # environment() references the captured OS enum, emitted as a string-literal
    # union alias derived from the members' serialized values (vow capture, no
    # BindOverride). Crystal's default Enum#to_json lowercases.
    dts.includes?("os: OS;").should be_true
    dts.includes?(%(export type OS = "darwin" | "linux" | "windows";)).should be_true
    # screen_info() is auto-derived from its NamedTuple return type
    dts.includes?("width: number; height: number; scale: number").should be_true
  end

  it "exports DragOut namespace with start binding (paths in the named-args object)" do
    bindings, plugins = drag_out_setup
    js = Lune::Generator.generate_runtime_js(bindings, plugins)

    js.includes?("export const Lune").should be_true
    js.includes?("DragOut:").should be_true
    js.includes?("start(args)").should be_true
    js.includes?(%(__lune.call("Lune.Plugins.DragOut.start", args))).should be_true
    js.scan(/start\(args\)/).size.should eq(1)
  end

  it "declares DragOut interface in runtime.d.ts" do
    bindings, plugins = drag_out_setup
    dts = Lune::Generator.generate_runtime_dts(bindings, plugins)

    dts.includes?("DragOut: {").should be_true
    dts.includes?("start(args: { paths: string[] })").should be_true
    dts.scan(/start\(args: \{ paths: string\[\] \}\)/).size.should eq(1)
  end

  describe "platform-unavailable stubs" do
    it "emits a rejecting JS stub for a filtered-out plugin" do
      js = Lune::Generator.generate_runtime_js(
        [] of Lune::Binding,
        [] of Lune::Plugin,
        [Lune::Plugins::DragOut.new] of Lune::Plugin,
      )

      js.includes?("export const Lune").should be_true
      js.includes?("DragOut").should be_true
      js.includes?("Promise.reject(new LuneError(\"UNAVAILABLE_ON_PLATFORM\"").should be_true
      js.includes?("Lune.Plugins.DragOut.start is not available on").should be_true
    end

    it "emits a same-shape d.ts interface for a filtered-out plugin" do
      dts = Lune::Generator.generate_runtime_dts(
        [] of Lune::Binding,
        [] of Lune::Plugin,
        [Lune::Plugins::DragOut.new] of Lune::Plugin,
      )

      dts.includes?("DragOut: {").should be_true
      dts.includes?("start(args: { paths: string[] }): Promise<void>").should be_true
    end

    it "does not duplicate a namespace when both live and unavailable lists name it" do
      # Belt-and-braces: if someone accidentally passes the same plugin in both
      # buckets, the live block wins and the stub is dropped.
      bindings, plugins = drag_out_setup
      js = Lune::Generator.generate_runtime_js(
        bindings,
        plugins,
        [Lune::Plugins::DragOut.new] of Lune::Plugin,
      )
      js.scan(/DragOut: \{/).size.should eq(1)
    end
  end

  it "generates App.d.ts with type literal namespaces and camelcased binding names" do
    bindings = [
      Lune::Binding.new(
        namespace: "alpha",
        method: "greet",
        args: [] of String,
        return_type: "String",
        internal: false,
        async: false
      ),
      Lune::Binding.new(
        namespace: "counter",
        method: "inc",
        args: [] of String,
        return_type: "Int32",
        internal: false,
        async: false
      ),
    ]

    dts = Lune::Generator.generate_app_dts(bindings)

    dts.includes?("export declare const alpha").should be_true
    dts.includes?("export declare const counter").should be_true
    dts.includes?("greet(").should be_true
    dts.includes?("inc(").should be_true
  end

  # vow's strict mapper refuses to silently widen an unknown struct arg to
  # `Record<string, any>`. Until the manifest captures the type (Phase 1), an
  # unmapped struct arg is a loud `UnmappableType` at generation time, not a lie
  # in the emitted `.d.ts`.
  it "raises on an unmappable struct arg type instead of widening it in App.d.ts" do
    bindings = [
      Lune::Binding.new(
        namespace: "math",
        method: "add",
        args: ["AddArgs"],
        return_type: "Int32",
        internal: false,
        async: false
      ),
    ]

    expect_raises(Vow::Codegen::UnmappableType) do
      Lune::Generator.generate_app_dts(bindings)
    end
  end

  it "writes .d.ts files alongside the JS files" do
    with_tempdir do |tmpdir|
      lunejs_dir = File.join(tmpdir, "lunejs")

      bindings = [
        Lune::Binding.new(
          namespace: "alpha",
          method: "greet",
          args: [] of String,
          return_type: "String",
          internal: false,
          async: false
        ),
      ]

      Lune::Generator.write_js(bindings, lunejs_dir)

      File.exists?(File.join(lunejs_dir, "runtime", "runtime.d.ts")).should be_true
      File.exists?(File.join(lunejs_dir, "app", "App.d.ts")).should be_true
    end
  end

  it "generates app API code with bindings" do
    bindings = [
      Lune::Binding.new(
        namespace: "alpha",
        method: "zeta",
        args: [] of String,
        return_type: "String",
        internal: false,
        async: false
      ),
      Lune::Binding.new(
        namespace: "counter",
        method: "alpha",
        args: [] of String,
        return_type: "String",
        internal: false,
        async: false
      ),
    ]

    js = Lune::Generator.generate_app_js(bindings)

    js.includes?("import { __lune }").should be_true
    js.includes?("return __lune.call(").should be_true

    js.includes?("export const alpha = {").should be_true
    js.includes?("export const counter = {").should be_true
    js.includes?("zeta(args = {})").should be_true
    js.includes?("alpha(args = {})").should be_true
  end

  it "includes namespace objects and a default export" do
    bindings = [
      Lune::Binding.new(
        namespace: "alpha",
        method: "ping",
        args: [] of String,
        return_type: "String",
        internal: false,
        async: false
      ),
      Lune::Binding.new(
        namespace: "counter",
        method: "sum",
        args: [] of String,
        return_type: "Int32",
        internal: false,
        async: false
      ),
    ]

    js = Lune::Generator.generate_app_js(bindings)

    js.includes?("export const alpha = {").should be_true
    js.includes?("export const counter = {").should be_true
  end

  it "generates app code even with no bindings" do
    js = Lune::Generator.generate_app_js([] of Lune::Binding)

    js.includes?("Generated by Lune").should be_true
    js.includes?("import { __lune }").should be_true
  end

  it "writes split app/runtime files to default location" do
    bindings = [
      Lune::Binding.new(
        namespace: "alpha",
        method: "ping",
        args: [] of String,
        return_type: "String",
        internal: false,
        async: false
      ),
      Lune::Binding.new(
        namespace: "counter",
        method: "sum",
        args: [] of String,
        return_type: "Int32",
        internal: false,
        async: false
      ),
    ]

    with_tempdir do |tmpdir|
      Dir.cd(tmpdir) do
        Lune::Generator.write_js(bindings, "frontend/lunejs")

        app_path = File.join("frontend", "lunejs", "app", "App.js")
        runtime_path = File.join("frontend", "lunejs", "runtime", "runtime.js")

        File.exists?(app_path).should be_true
        File.exists?(runtime_path).should be_true

        app_js = File.read(app_path)
        runtime_js = File.read(runtime_path)

        app_js.includes?("export const alpha = {").should be_true
        app_js.includes?("export const counter = {").should be_true
        app_js.includes?("return __lune.call(").should be_true

        runtime_js.includes?("export const __lune").should be_true
      end
    end
  end

  it "writes to a custom lunejs_dir" do
    with_tempdir do |tmpdir|
      lunejs_dir = File.join(tmpdir, "lunejs")

      bindings = [
        Lune::Binding.new(
          namespace: "alpha",
          method: "hello",
          args: [] of String,
          return_type: "String",
          internal: false,
          async: false
        ),
      ]

      Lune::Generator.write_js(bindings, lunejs_dir)

      app_path = File.join(lunejs_dir, "app", "App.js")
      runtime_path = File.join(lunejs_dir, "runtime", "runtime.js")

      File.exists?(app_path).should be_true
      File.exists?(runtime_path).should be_true
      File.read(app_path).includes?("export const alpha = {").should be_true
    end
  end

  it "does not rewrite files when content is unchanged" do
    with_tempdir do |tmpdir|
      lunejs_dir = File.join(tmpdir, "lunejs")

      Lune::Generator.write_js([
        Lune::Binding.new(
          namespace: "alpha",
          method: "ping",
          args: [] of String,
          return_type: "String",
          internal: false,
          async: false
        ),
      ], lunejs_dir)

      app_path = File.join(lunejs_dir, "app", "App.js")
      mtime_before = File.info(app_path).modification_time

      sleep 100.milliseconds

      Lune::Generator.write_js([
        Lune::Binding.new(
          namespace: "alpha",
          method: "ping",
          args: [] of String,
          return_type: "String",
          internal: false,
          async: false
        ),
      ], lunejs_dir)

      mtime_after = File.info(app_path).modification_time
      mtime_after.should eq(mtime_before)
    end
  end

  it "rewrites files when binding names change" do
    with_tempdir do |tmpdir|
      lunejs_dir = File.join(tmpdir, "lunejs")

      Lune::Generator.write_js([
        Lune::Binding.new(
          namespace: "alpha",
          method: "ping",
          args: [] of String,
          return_type: "String",
          internal: false,
          async: false
        ),
      ], lunejs_dir)

      app_path = File.join(lunejs_dir, "app", "App.js")
      mtime_before = File.info(app_path).modification_time

      sleep 100.milliseconds

      Lune::Generator.write_js([
        Lune::Binding.new(
          namespace: "alpha",
          method: "ping",
          args: [] of String,
          return_type: "String",
          internal: false,
          async: false
        ),
        Lune::Binding.new(
          namespace: "alpha",
          method: "pong",
          args: [] of String,
          return_type: "String",
          internal: false,
          async: false
        ),
      ], lunejs_dir)

      mtime_after = File.info(app_path).modification_time

      mtime_after.should_not eq(mtime_before)
      File.read(app_path).includes?("export const alpha = {").should be_true
      File.read(app_path).includes?("pong(args = {})").should be_true
    end
  end
end
