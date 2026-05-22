require "../spec_helper"
require "file_utils"

private def runtime_bindings
  app = Lune::App.new
  Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new).all.each { |cap| app.install(cap) }
  app.bindings.select(&.internal?)
end

private def events_caps
  [Lune::Plugins::Events.new] of Lune::Plugin
end

private def drag_out_caps
  [Lune::Plugins::DragOut.new] of Lune::Plugin
end

private def drag_out_setup
  cap = Lune::Plugins::DragOut.new
  app = Lune::App.new
  app.install(cap)
  {app.bindings, [cap] of Lune::Plugin}
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

  it "exports Events namespace with on, once, off helpers" do
    js = Lune::Generator.generate_runtime_js([] of Lune::Binding, events_caps)

    js.includes?("export const Lune").should be_true
    js.includes?("Events:").should be_true
    js.includes?("on(name, cb)").should be_true
    js.includes?("once(name, cb)").should be_true
    js.includes?("off(name, cb)").should be_true
    js.includes?("window.__lune.on").should be_true
    js.includes?("window.__lune.off").should be_true
  end

  it "exports emit as a regular @[Bind] method on Events" do
    # emit moved from js_helpers into a real binding (Events.emit). Plugin
    # bindings are passed explicitly to the generator alongside the cap.
    events = Lune::Plugins::Events.new
    app = Lune::App.new
    app.install(events)
    js = Lune::Generator.generate_runtime_js(app.bindings.select(&.internal?), events_caps)

    js.includes?("emit(name, data)").should be_true
    js.includes?(%("Lune.Plugins.Events.emit")).should be_true
  end

  it "declares emit in runtime.d.ts" do
    events = Lune::Plugins::Events.new
    app = Lune::App.new
    app.install(events)
    dts = Lune::Generator.generate_runtime_dts(app.bindings.select(&.internal?), events_caps)

    dts.includes?("emit(name: string").should be_true
  end

  it "exports System namespace with quit, openUrl, environment" do
    js = Lune::Generator.generate_runtime_js(runtime_bindings)

    js.includes?("export const Lune").should be_true
    js.includes?("System:").should be_true
    js.includes?("quit()").should be_true
    js.includes?("openUrl(").should be_true
    js.includes?("environment()").should be_true
    js.includes?("Lune.Plugins.System.quit").should be_true
    js.includes?("Lune.Plugins.System.open_url").should be_true
    js.includes?("Lune.Plugins.System.environment").should be_true
  end

  it "generates runtime.d.ts with typed namespace interfaces" do
    dts = Lune::Generator.generate_runtime_dts(runtime_bindings, events_caps)

    dts.includes?("LuneEnvironment").should be_true
    dts.includes?("export declare const Lune").should be_true
    dts.includes?("System: {").should be_true
    dts.includes?("Events: {").should be_true
    dts.includes?("quit()").should be_true
    dts.includes?("openUrl(").should be_true
    dts.includes?("environment()").should be_true
    dts.includes?("on(name: string").should be_true
    dts.includes?("once(name: string").should be_true
    dts.includes?("off(name: string").should be_true
  end

  it "exports DragOut namespace with start binding (paths JSON-stringified)" do
    bindings, caps = drag_out_setup
    js = Lune::Generator.generate_runtime_js(bindings, caps)

    js.includes?("export const Lune").should be_true
    js.includes?("DragOut:").should be_true
    js.includes?("start(paths)").should be_true
    js.includes?("JSON.stringify(paths || [])").should be_true
    js.scan(/start\(paths\)/).size.should eq(1)
  end

  it "declares DragOut interface in runtime.d.ts" do
    bindings, caps = drag_out_setup
    dts = Lune::Generator.generate_runtime_dts(bindings, caps)

    dts.includes?("DragOut: {").should be_true
    dts.includes?("start(paths: string[])").should be_true
    dts.scan(/start\(paths: string\[\]\)/).size.should eq(1)
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
      dts.includes?("start(paths: string[]): Promise<void>").should be_true
    end

    it "does not duplicate a namespace when both live and unavailable lists name it" do
      # Belt-and-braces: if someone accidentally passes the same cap in both
      # buckets, the live block wins and the stub is dropped.
      bindings, caps = drag_out_setup
      js = Lune::Generator.generate_runtime_js(
        bindings,
        caps,
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
        callback: ->(_args : Array(JSON::Any)) { JSON::Any.new("ok") },
        internal: false,
        async: false
      ),
      Lune::Binding.new(
        namespace: "counter",
        method: "inc",
        args: [] of String,
        return_type: "Number",
        callback: ->(_args : Array(JSON::Any)) { JSON::Any.new(1_i64) },
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

  it "maps JSON::Serializable struct args to Record<string, any> in App.d.ts" do
    bindings = [
      Lune::Binding.new(
        namespace: "math",
        method: "add",
        args: ["AddArgs"],
        return_type: "Int32",
        callback: ->(_args : Array(JSON::Any)) { JSON::Any.new(0_i64) },
        internal: false,
        async: false
      ),
    ]

    dts = Lune::Generator.generate_app_dts(bindings)

    dts.includes?("arg0: Record<string, any>").should be_true
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
          callback: ->(_args : Array(JSON::Any)) { JSON::Any.new("ok") },
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
        callback: ->(_args : Array(JSON::Any)) { JSON::Any.new("ok") },
        internal: false,
        async: false
      ),
      Lune::Binding.new(
        namespace: "counter",
        method: "alpha",
        args: [] of String,
        return_type: "String",
        callback: ->(_args : Array(JSON::Any)) { JSON::Any.new("ok") },
        internal: false,
        async: false
      ),
    ]

    js = Lune::Generator.generate_app_js(bindings)

    js.includes?("import { __lune }").should be_true
    js.includes?("return __lune.call(").should be_true

    js.includes?("export const alpha = {").should be_true
    js.includes?("export const counter = {").should be_true
    js.includes?("zeta()").should be_true
    js.includes?("alpha()").should be_true
  end

  it "includes namespace objects and a default export" do
    bindings = [
      Lune::Binding.new(
        namespace: "alpha",
        method: "ping",
        args: [] of String,
        return_type: "String",
        callback: ->(_args : Array(JSON::Any)) { JSON::Any.new("ok") },
        internal: false,
        async: false
      ),
      Lune::Binding.new(
        namespace: "counter",
        method: "sum",
        args: [] of String,
        return_type: "Int32",
        callback: ->(_args : Array(JSON::Any)) { JSON::Any.new(0_i64) },
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
        callback: ->(_args : Array(JSON::Any)) { JSON::Any.new("ok") },
        internal: false,
        async: false
      ),
      Lune::Binding.new(
        namespace: "counter",
        method: "sum",
        args: [] of String,
        return_type: "Int32",
        callback: ->(_args : Array(JSON::Any)) { JSON::Any.new(0_i64) },
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
          callback: ->(_args : Array(JSON::Any)) { JSON::Any.new("ok") },
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
          callback: ->(_args : Array(JSON::Any)) { JSON::Any.new("ok") },
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
          callback: ->(_args : Array(JSON::Any)) { JSON::Any.new("ok") },
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
          callback: ->(_args : Array(JSON::Any)) { JSON::Any.new("ok") },
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
          callback: ->(_args : Array(JSON::Any)) { JSON::Any.new("ok") },
          internal: false,
          async: false
        ),
        Lune::Binding.new(
          namespace: "alpha",
          method: "pong",
          args: [] of String,
          return_type: "String",
          callback: ->(_args : Array(JSON::Any)) { JSON::Any.new("ok") },
          internal: false,
          async: false
        ),
      ], lunejs_dir)

      mtime_after = File.info(app_path).modification_time

      mtime_after.should_not eq(mtime_before)
      File.read(app_path).includes?("export const alpha = {").should be_true
      File.read(app_path).includes?("pong()").should be_true
    end
  end
end
