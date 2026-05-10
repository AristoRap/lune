require "./spec_helper"
require "file_utils"

private def with_tempdir(& : String -> _)
  dir = File.join(Dir.tempdir, "lune_rt_#{Random.new.hex(8)}")
  Dir.mkdir_p(dir)
  begin
    yield dir
  ensure
    FileUtils.rm_rf(dir)
  end
end

describe Lune::Runtime do
  it "generates runtime transport code" do
    js = Lune::Runtime.generate_runtime_js

    js.includes?("__lune").should be_true
    js.includes?("export const __lune").should be_true
  end

  it "exports on, once, off event bus helpers" do
    js = Lune::Runtime.generate_runtime_js

    js.includes?("export function on").should be_true
    js.includes?("export function once").should be_true
    js.includes?("export function off").should be_true
    js.includes?("__lune_on").should be_true
    js.includes?("__lune_off").should be_true
  end

  it "generates app API code with bindings" do
    js = Lune::Runtime.generate_app_js(["zeta", "alpha"])

    js.includes?("import { __lune }").should be_true
    js.includes?("return __lune.call(").should be_true

    js.includes?("export function zeta").should be_true
    js.includes?("export function alpha").should be_true
  end

  it "includes a Proxy-based api for dynamic dispatch at build time" do
    js = Lune::Runtime.generate_app_js(["ping", "sum"])

    js.includes?("Proxy").should be_true
    js.includes?("__makeApi").should be_true
    js.includes?("export const api").should be_true
    js.includes?("export default api").should be_true
  end

  it "generates proxy api even with no binding names" do
    js = Lune::Runtime.generate_app_js([] of String)

    js.includes?("Proxy").should be_true
    js.includes?("__makeApi").should be_true
    js.includes?("export const api").should be_true
  end

  it "writes split app/runtime files to default location" do
    Lune::Runtime.write_js(["ping", "sum"])

    app_path = File.join("frontend", "lunejs", "app", "App.js")
    runtime_path = File.join("frontend", "lunejs", "runtime", "runtime.js")

    File.exists?(app_path).should be_true
    File.exists?(runtime_path).should be_true

    app_js = File.read(app_path)
    runtime_js = File.read(runtime_path)

    app_js.includes?("export function ping").should be_true
    app_js.includes?("export function sum").should be_true
    app_js.includes?("return __lune.call(").should be_true

    runtime_js.includes?("export const __lune").should be_true
  end

  it "writes to a custom lunejs_dir" do
    with_tempdir do |tmpdir|
      lunejs_dir = File.join(tmpdir, "lunejs")
      Lune::Runtime.write_js(["hello"], lunejs_dir)

      app_path     = File.join(lunejs_dir, "app", "App.js")
      runtime_path = File.join(lunejs_dir, "runtime", "runtime.js")

      File.exists?(app_path).should be_true
      File.exists?(runtime_path).should be_true
      File.read(app_path).includes?("export function hello").should be_true
    end
  end

  it "does not rewrite files when content is unchanged" do
    with_tempdir do |tmpdir|
      lunejs_dir = File.join(tmpdir, "lunejs")
      Lune::Runtime.write_js(["ping"], lunejs_dir)

      app_path = File.join(lunejs_dir, "app", "App.js")
      mtime_before = File.info(app_path).modification_time

      sleep 20.milliseconds

      Lune::Runtime.write_js(["ping"], lunejs_dir)
      mtime_after = File.info(app_path).modification_time

      mtime_after.should eq(mtime_before)
    end
  end

  it "rewrites files when binding names change" do
    with_tempdir do |tmpdir|
      lunejs_dir = File.join(tmpdir, "lunejs")
      Lune::Runtime.write_js(["ping"], lunejs_dir)

      app_path = File.join(lunejs_dir, "app", "App.js")
      mtime_before = File.info(app_path).modification_time

      sleep 20.milliseconds

      Lune::Runtime.write_js(["ping", "pong"], lunejs_dir)
      mtime_after = File.info(app_path).modification_time

      mtime_after.should_not eq(mtime_before)
      File.read(app_path).includes?("export function pong").should be_true
    end
  end
end
