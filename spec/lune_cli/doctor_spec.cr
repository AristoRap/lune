require "../spec_helper"

# A user-defined plugin outside the framework's namespace, used to exercise
# `built_in?` returning false.
private class UserSidePlugin < Lune::Plugin
  DESCRIPTOR = Descriptor.new(id: :user_side_plugin, label: "UserSide")

  def descriptor : Descriptor
    DESCRIPTOR
  end
end

private def framed_manifest(json : String) : String
  String.build do |s|
    s << "build chatter we ignore\n"
    s << "<<<LUNE_MANIFEST\n"
    s << json << "\n"
    s << "LUNE_MANIFEST>>>\n"
    s << "trailing noise\n"
  end
end

private def sample_manifest : Vow::Manifest
  Vow::Manifest.new(
    procedures: [
      Vow::ProcedureDescriptor.new(
        name: "Lune.Plugins.Window.setSize",
        args: [Vow::ArgDescriptor.new("width", "Int32"), Vow::ArgDescriptor.new("height", "Int32")],
        return_type: "Nil",
      ),
      Vow::ProcedureDescriptor.new(
        name: "Lune.Plugins.System.environment",
        args: [] of Vow::ArgDescriptor,
        return_type: "Environment",
      ),
    ],
    types: [
      Vow::TypeDescriptor.new(
        name: "Environment",
        crystal_name: "Lune::Plugins::System::Environment",
        fields: [Vow::FieldDescriptor.new("os", "OS"), Vow::FieldDescriptor.new("arch", "String")],
      ),
      Vow::TypeDescriptor.new(
        name: "OS",
        crystal_name: "Lune::Plugins::System::OS",
        fields: [] of Vow::FieldDescriptor,
        kind: "enum",
        members: ["darwin", "linux", "windows"],
      ),
    ],
  )
end

# Doctor only prints plugins with `--plugins` (the inspect-mode compile is
# slow). Default mode is env checks only. The plugin sections — `built-in:`
# (from `Lune.registered_plugins` inside the CLI binary) and `imported:`
# (from compiling app_entry with `-Dlune_inspect`) — both use the same
# enabled/disabled marking, gated on the user's `lune.yml`.
describe LuneCLI::Commands::Doctor do
  describe "default mode (no --plugins)" do
    it "skips both plugin sections" do
      output = IO::Memory.new
      config = LuneCLI::Config.new
      config.app_entry = __FILE__
      LuneCLI::Commands::Doctor.new.run(config, output: output)
      report = output.to_s
      report.should_not contain("built-in:")
      report.should_not contain("imported:")
    end
  end

  describe "built_in? on Lune::Plugin" do
    it "is true for plugins under Lune::Plugins" do
      Lune::Plugins::Tray.new.built_in?.should be_true
      Lune::Plugins::Event.new.built_in?.should be_true
    end

    it "is false for user-defined plugins outside that namespace" do
      UserSidePlugin.new.built_in?.should be_false
    end
  end

  describe "parser" do
    it "parses framed inspect-mode output and reads the built_in flag" do
      doctor = LuneCLI::Commands::Doctor.new
      framed = String.build do |s|
        s << "build chatter we ignore\n"
        s << "<<<LUNE_PLUGINS\n"
        s << "tray\tTray\tdarwin,linux,win32\ttrue\n"
        s << "counter\tCounter\tdarwin,linux,win32\tfalse\n"
        s << "LUNE_PLUGINS>>>\n"
      end
      rows = doctor.parse_inspect_output_for_spec(framed)
      rows.map { |r| r[:id] }.should eq(["tray", "counter"])
      rows.find { |r| r[:id] == "tray" }.not_nil![:built_in].should be_true
      rows.find { |r| r[:id] == "counter" }.not_nil![:built_in].should be_false
    end

    it "drops rows with too few columns" do
      doctor = LuneCLI::Commands::Doctor.new
      framed = "<<<LUNE_PLUGINS\nfoo\tFoo\tdarwin\nLUNE_PLUGINS>>>\n" # missing built_in col
      doctor.parse_inspect_output_for_spec(framed).should be_empty
    end
  end

  # `--api` compiles app_entry with `-Dlune_inspect_api`, which emits the live
  # `Vow::Manifest` JSON framed by `<<<LUNE_MANIFEST` / `LUNE_MANIFEST>>>`.
  # Doctor lifts the JSON out of the captured stdout (build chatter and all),
  # parses it, and renders a human contract table — or, with `--json`, prints
  # the raw manifest straight through for tooling.
  describe "manifest introspection (--api)" do
    it "lifts the framed manifest JSON out of captured stdout" do
      doctor = LuneCLI::Commands::Doctor.new
      manifest = doctor.parse_manifest_output_for_spec(framed_manifest(sample_manifest.to_json))
      manifest.procedures.map(&.name).should eq([
        "Lune.Plugins.Window.setSize",
        "Lune.Plugins.System.environment",
      ])
      manifest.types.map(&.name).should eq(["Environment", "OS"])
    end

    it "raises a clear error when no manifest block is present" do
      doctor = LuneCLI::Commands::Doctor.new
      expect_raises(Exception, /no manifest/i) do
        doctor.parse_manifest_output_for_spec("just build chatter, no markers")
      end
    end

    it "renders a procedure-and-types contract table" do
      doctor = LuneCLI::Commands::Doctor.new
      output = IO::Memory.new
      doctor.print_manifest_table_for_spec(sample_manifest, output)
      report = output.to_s

      report.should contain("procedures (2)")
      report.should contain("Lune.Plugins.Window.setSize(width: Int32, height: Int32) -> Nil")
      report.should contain("Lune.Plugins.System.environment() -> Environment")
      report.should contain("types (2)")
      report.should contain("Environment")
      report.should contain("OS = \"darwin\" | \"linux\" | \"windows\"")
    end
  end
end
