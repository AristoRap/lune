require "../spec_helper"
require "yaml"
require "digest/sha256"

describe "Vendor dependency guardrails" do
  it "pins webview to the expected upstream commit" do
    lock = YAML.parse(File.read("shard.lock"))
    version = lock["shards"]["webview"]["version"].as_s

    # Update this only when intentionally upgrading webview.
    version.should contain("fff6c392dace786cdab31f54fc5b8073c5efa95d")
  end

  it "pins upstream source location in root shard.yml" do
    root = YAML.parse(File.read("shard.yml"))
    webview = root["dependencies"]["webview"]

    webview["github"].as_s.should eq("naqvis/webview")
  end

  it "detects vendored source drift via file fingerprints" do
    expected = {
      "lib/webview/src/webview.cr" => "0ca91caf341880a9b005aa00a141c551f0abfbdc9a5532ed1fbf3d90ea8c0720",
      "lib/webview/src/lib.cr"     => "75e4fcc77c772d855b386ca0552463831ded2fdbb5a647fb6de57788bfb80d8e",
      "lib/webview/shard.yml"      => "62cab056926ba89fdc6b16a7aedcffaf98e888fd3db3554f1a0b4ce3aa3ba82c",
    }

    expected.each do |path, sha|
      Digest::SHA256.hexdigest(File.read(path)).should eq(sha)
    end
  end

  it "fails fast if webview api surface used by lune disappears" do
    typeof(Webview::Webview.allocate.bind("ping", Webview::JSProc.new { |_| JSON::Any.new(nil) }))
    typeof(Webview::Webview.allocate.dispatch { nil })
    typeof(Webview::Webview.allocate.eval("1 + 1"))
    typeof(Webview::Webview.allocate.navigate("http://127.0.0.1"))
  end
end
