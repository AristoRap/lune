require "./spec_helper"
require "log"

describe Lune do
  it "exposes a default logger" do
    Lune.default_logger.should be_a(Log)
  end

  it "defaults to info logging" do
    Lune.default_logger.level.should eq(Log::Severity::Info)
  end

  it "supports global logger injection" do
    original = Lune.logger
    custom = Log.for("lune.spec.custom")

    begin
      Lune.logger = custom
      Lune.logger.should eq(custom)
    ensure
      Lune.logger = original
    end
  end

  it "supports configure block updates" do
    original = Lune.logger
    custom = Log.for("lune.spec.configure")

    begin
      Lune.configure do |config|
        config.logger = custom
      end

      Lune.logger.should eq(custom)
    ensure
      Lune.logger = original
    end
  end

  it "can raise the global logger level to debug" do
    original = Lune.logger
    custom = Log.for("lune.spec.debug")
    custom.level = Log::Severity::None

    begin
      Lune.logger = custom

      Lune.enable_debug_logging

      Lune.logger.level.should eq(Log::Severity::Debug)
    ensure
      Lune.logger = original
    end
  end

  it "can restore the global logger level to info" do
    original = Lune.logger
    custom = Log.for("lune.spec.info")
    custom.level = Log::Severity::None

    begin
      Lune.logger = custom

      Lune.enable_standard_logging

      Lune.logger.level.should eq(Log::Severity::Info)
    ensure
      Lune.logger = original
    end
  end
end
