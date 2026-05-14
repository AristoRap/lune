require "../spec_helper"

private def build_path_bridge
  fake = FakeWebview.new
  bridge = Lune::Bridge.new(fake)
  bridge.register_bindings(Lune::PathBindings.build)
  {fake, bridge}
end

private def invoke_path(fake, bridge, name)
  fake, bridge = build_path_bridge
  fake.invoke("runtime.__lune.#{name}", "seq-1", [] of JSON::Any)
  _seq, status, result = fake.resolve_calls[0]
  {status, JSON.parse(result).as_s}
end

describe Lune::PathBindings do
  describe ".build" do
    it "marks all bindings as internal" do
      Lune::PathBindings.build.all?(&.internal).should be_true
    end

    it "registers under the runtime namespace" do
      Lune::PathBindings.build.all? { |b| b.namespace == "runtime" }.should be_true
    end

    describe "__lune.homeDir" do
      it "resolves successfully" do
        fake, bridge = build_path_bridge
        fake.invoke("runtime.__lune.homeDir", "seq-1", [] of JSON::Any)
        _seq, status, _ = fake.resolve_calls[0]
        status.should eq(0)
      end

      it "returns a non-empty string" do
        fake, bridge = build_path_bridge
        fake.invoke("runtime.__lune.homeDir", "seq-1", [] of JSON::Any)
        _, _, result = fake.resolve_calls[0]
        JSON.parse(result).as_s.should_not be_empty
      end

      it "matches Crystal Path.home" do
        fake, bridge = build_path_bridge
        fake.invoke("runtime.__lune.homeDir", "seq-1", [] of JSON::Any)
        _, _, result = fake.resolve_calls[0]
        JSON.parse(result).as_s.should eq(Path.home.to_s)
      end
    end

    describe "__lune.tempDir" do
      it "resolves successfully" do
        fake, bridge = build_path_bridge
        fake.invoke("runtime.__lune.tempDir", "seq-1", [] of JSON::Any)
        _seq, status, _ = fake.resolve_calls[0]
        status.should eq(0)
      end

      it "returns a non-empty string" do
        fake, bridge = build_path_bridge
        fake.invoke("runtime.__lune.tempDir", "seq-1", [] of JSON::Any)
        _, _, result = fake.resolve_calls[0]
        JSON.parse(result).as_s.should_not be_empty
      end

      it "matches Crystal Dir.tempdir" do
        fake, bridge = build_path_bridge
        fake.invoke("runtime.__lune.tempDir", "seq-1", [] of JSON::Any)
        _, _, result = fake.resolve_calls[0]
        JSON.parse(result).as_s.should eq(Dir.tempdir)
      end
    end

    describe "__lune.downloadsDir" do
      it "resolves successfully" do
        fake, bridge = build_path_bridge
        fake.invoke("runtime.__lune.downloadsDir", "seq-1", [] of JSON::Any)
        _seq, status, _ = fake.resolve_calls[0]
        status.should eq(0)
      end

      it "returns a path under the home directory" do
        fake, bridge = build_path_bridge
        fake.invoke("runtime.__lune.downloadsDir", "seq-1", [] of JSON::Any)
        _, _, result = fake.resolve_calls[0]
        JSON.parse(result).as_s.should start_with(Path.home.to_s)
      end
    end

    describe "__lune.appDataDir" do
      it "resolves successfully" do
        fake, bridge = build_path_bridge
        fake.invoke("runtime.__lune.appDataDir", "seq-1", [] of JSON::Any)
        _seq, status, _ = fake.resolve_calls[0]
        status.should eq(0)
      end

      it "returns a non-empty string" do
        fake, bridge = build_path_bridge
        fake.invoke("runtime.__lune.appDataDir", "seq-1", [] of JSON::Any)
        _, _, result = fake.resolve_calls[0]
        JSON.parse(result).as_s.should_not be_empty
      end
    end
  end
end
