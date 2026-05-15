require "../spec_helper"
require "file_utils"

describe Lune::Runtime do
  it "generates runtime transport code" do
    js = Lune::Runtime::Generator.generate_runtime_js

    js.includes?("__lune").should be_true
    js.includes?("export const __lune").should be_true
  end

  it "exports on, once, off event bus helpers" do
    js = Lune::Runtime::Generator.generate_runtime_js

    js.includes?("export function on").should be_true
    js.includes?("export function once").should be_true
    js.includes?("export function off").should be_true
    js.includes?("__lune_on").should be_true
    js.includes?("__lune_off").should be_true
  end

  it "exports quit, openURL, environment runtime functions" do
    js = Lune::Runtime::Generator.generate_runtime_js

    js.includes?("export function quit").should be_true
    js.includes?("export function openURL").should be_true
    js.includes?("export function environment").should be_true
    js.includes?("__lune.quit").should be_true
    js.includes?("__lune.openURL").should be_true
    js.includes?("__lune.environment").should be_true
  end

  it "generates runtime.d.ts with typed declarations" do
    dts = Lune::Runtime::Generator.generate_runtime_dts

    dts.includes?("LuneEnvironment").should be_true
    dts.includes?("export declare function quit").should be_true
    dts.includes?("export declare function openURL").should be_true
    dts.includes?("export declare function environment").should be_true
    dts.includes?("export declare function on").should be_true
    dts.includes?("export declare function once").should be_true
    dts.includes?("export declare function off").should be_true
  end

  it "generates App.d.ts with namespace interfaces and camelcased binding names" do
    bindings = [
      Lune::BindingDef.new(
        name: "greet",
        namespace: "alpha",
        args: [] of String,
        return_type: "String",
        callback: ->(_args : Array(JSON::Any)) { JSON::Any.new("ok") },
        internal: false,
        async: false
      ),
      Lune::BindingDef.new(
        name: "inc",
        namespace: "counter",
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
    dts.includes?("Greet(").should be_true
    dts.includes?("Inc(").should be_true
    dts.includes?("export interface Api").should be_true
    dts.includes?("alpha: alpha;").should be_true
    dts.includes?("counter: counter;").should be_true
    dts.includes?("export declare const api: Api;").should be_true
  end

  it "maps JSON::Serializable struct args to Record<string, any> in App.d.ts" do
    bindings = [
      Lune::BindingDef.new(
        name: "add",
        namespace: "math",
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
        Lune::BindingDef.new(
          name: "greet",
          namespace: "alpha",
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
      Lune::BindingDef.new(
        name: "zeta",
        namespace: "alpha",
        args: [] of String,
        return_type: "String",
        callback: ->(_args : Array(JSON::Any)) { JSON::Any.new("ok") },
        internal: false,
        async: false
      ),
      Lune::BindingDef.new(
        name: "alpha",
        namespace: "counter",
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
    js.includes?("Zeta(...args)").should be_true
    js.includes?("Alpha(...args)").should be_true
  end

  it "includes namespace objects and a default export" do
    bindings = [
      Lune::BindingDef.new(
        name: "ping",
        namespace: "alpha",
        args: [] of String,
        return_type: "String",
        callback: ->(_args : Array(JSON::Any)) { JSON::Any.new("ok") },
        internal: false,
        async: false
      ),
      Lune::BindingDef.new(
        name: "sum",
        namespace: "counter",
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
    js = Lune::Runtime::Generator.generate_app_js([] of Lune::BindingDef)

    js.includes?("export const api").should be_true
    js.includes?("export default api").should be_true
  end

  it "writes split app/runtime files to default location" do
    bindings = [
      Lune::BindingDef.new(
        name: "ping",
        namespace: "alpha",
        args: [] of String,
        return_type: "String",
        callback: ->(_args : Array(JSON::Any)) { JSON::Any.new("ok") },
        internal: false,
        async: false
      ),
      Lune::BindingDef.new(
        name: "sum",
        namespace: "counter",
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
        Lune::BindingDef.new(
          name: "hello",
          namespace: "alpha",
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
        Lune::BindingDef.new(
          name: "ping",
          namespace: "alpha",
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
        Lune::BindingDef.new(
          name: "ping",
          namespace: "alpha",
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
        Lune::BindingDef.new(
          name: "ping",
          namespace: "alpha",
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
        Lune::BindingDef.new(
          name: "ping",
          namespace: "alpha",
          args: [] of String,
          return_type: "String",
          callback: ->(_args : Array(JSON::Any)) { JSON::Any.new("ok") },
          internal: false,
          async: false
        ),
        Lune::BindingDef.new(
          name: "pong",
          namespace: "alpha",
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
      File.read(app_path).includes?("Pong(...args)").should be_true
    end
  end
end
