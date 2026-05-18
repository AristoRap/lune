require "../spec_helper"
require "file_utils"

private def runtime_bindings
  app = Lune::App.new
  Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new).all.each(&.install(app))
  app.bindings.select(&.internal?)
end

private def event_bus_caps
  [Lune::Capabilities::EventBus.new] of Lune::Capability
end

private def drag_out_caps
  [Lune::Capabilities::DragOut.new(Pointer(Void).null)] of Lune::Capability
end

describe Lune::Runtime do
  it "generates runtime transport code" do
    js = Lune::Runtime::Generator.generate_runtime_js([] of Lune::Binding)

    js.includes?("__lune").should be_true
    js.includes?("export const __lune").should be_true
  end

  it "exports LuneError class that extends Error" do
    js = Lune::Runtime::Generator.generate_runtime_js([] of Lune::Binding)

    js.includes?("export class LuneError extends Error").should be_true
    js.includes?("this.name = \"LuneError\"").should be_true
    js.includes?("this.code = code").should be_true
  end

  it "wraps __lune.call to convert plain error envelopes to LuneError instances" do
    js = Lune::Runtime::Generator.generate_runtime_js([] of Lune::Binding)

    js.includes?(".catch(").should be_true
    js.includes?("new LuneError(").should be_true
  end

  it "declares LuneError as a class in runtime.d.ts" do
    dts = Lune::Runtime::Generator.generate_runtime_dts([] of Lune::Binding)

    dts.includes?("export declare class LuneError extends Error").should be_true
    dts.includes?("readonly code: string").should be_true
  end

  it "exports Events namespace with on, once, off helpers" do
    js = Lune::Runtime::Generator.generate_runtime_js([] of Lune::Binding, event_bus_caps)

    js.includes?("export const Events").should be_true
    js.includes?("on(name, cb)").should be_true
    js.includes?("once(name, cb)").should be_true
    js.includes?("off(name, cb)").should be_true
    js.includes?("window.__lune.on").should be_true
    js.includes?("window.__lune.off").should be_true
  end

  it "exports emit for JS-to-Crystal events" do
    js = Lune::Runtime::Generator.generate_runtime_js([] of Lune::Binding, event_bus_caps)

    js.includes?("emit(name, data)").should be_true
    js.includes?("__lune.jsEmit").should be_true
  end

  it "declares emit in runtime.d.ts" do
    dts = Lune::Runtime::Generator.generate_runtime_dts([] of Lune::Binding, event_bus_caps)

    dts.includes?("emit(name: string").should be_true
  end

  it "exports System namespace with quit, openUrl, environment" do
    js = Lune::Runtime::Generator.generate_runtime_js(runtime_bindings)

    js.includes?("export const System").should be_true
    js.includes?("quit()").should be_true
    js.includes?("openUrl(").should be_true
    js.includes?("environment()").should be_true
    js.includes?("__lune.system.quit").should be_true
    js.includes?("__lune.system.open_url").should be_true
    js.includes?("__lune.system.environment").should be_true
  end

  it "generates runtime.d.ts with typed namespace interfaces" do
    dts = Lune::Runtime::Generator.generate_runtime_dts(runtime_bindings, event_bus_caps)

    dts.includes?("LuneEnvironment").should be_true
    dts.includes?("export interface System").should be_true
    dts.includes?("quit()").should be_true
    dts.includes?("openUrl(").should be_true
    dts.includes?("environment()").should be_true
    dts.includes?("export interface Events").should be_true
    dts.includes?("on(name: string").should be_true
    dts.includes?("once(name: string").should be_true
    dts.includes?("off(name: string").should be_true
  end

  it "exports DragOut namespace with start helper" do
    js = Lune::Runtime::Generator.generate_runtime_js([] of Lune::Binding, drag_out_caps)

    js.includes?("export const DragOut").should be_true
    js.includes?("start(paths)").should be_true
  end

  it "declares DragOut interface in runtime.d.ts" do
    dts = Lune::Runtime::Generator.generate_runtime_dts([] of Lune::Binding, drag_out_caps)

    dts.includes?("export interface DragOut").should be_true
    dts.includes?("start(paths: string[])").should be_true
  end

  it "generates App.d.ts with namespace interfaces and camelcased binding names" do
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

    dts = Lune::Runtime::Generator.generate_app_dts(bindings)

    dts.includes?("export interface alpha").should be_true
    dts.includes?("export interface counter").should be_true
    dts.includes?("greet(").should be_true
    dts.includes?("inc(").should be_true
    dts.includes?("export interface Api").should be_true
    dts.includes?("alpha: alpha;").should be_true
    dts.includes?("counter: counter;").should be_true
    dts.includes?("export declare const api: Api;").should be_true
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

    dts = Lune::Runtime::Generator.generate_app_dts(bindings)

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

      Lune::Runtime::Generator.write_js(bindings, lunejs_dir)

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

    js = Lune::Runtime::Generator.generate_app_js(bindings)

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

    js = Lune::Runtime::Generator.generate_app_js(bindings)

    js.includes?("export const api").should be_true
    js.includes?("export default api").should be_true
    js.includes?("export const alpha = {").should be_true
    js.includes?("export const counter = {").should be_true
  end

  it "generates app API code even with no bindings" do
    js = Lune::Runtime::Generator.generate_app_js([] of Lune::Binding)

    js.includes?("export const api").should be_true
    js.includes?("export default api").should be_true
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
        Lune::Runtime::Generator.write_js(bindings)

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

      Lune::Runtime::Generator.write_js(bindings, lunejs_dir)

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

      Lune::Runtime::Generator.write_js([
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

      Lune::Runtime::Generator.write_js([
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

      Lune::Runtime::Generator.write_js([
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

      Lune::Runtime::Generator.write_js([
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
