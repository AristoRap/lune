require "../spec_helper"

# A user-defined plugin outside the framework's namespace, used to exercise
# `built_in?` returning false.
private class UserSidePlugin < Lune::Plugin
  DESCRIPTOR = Descriptor.new(id: :user_side_plugin, label: "UserSide")

  def descriptor : Descriptor
    DESCRIPTOR
  end
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
end
