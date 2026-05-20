require "log"

module Lune
  class LogConfig
    property logger : Log

    def initialize(@logger : Log = Lune.default_logger)
    end
  end

  def self.default_logger : Log
    # LUNE_LOG=debug (or trace/warn/error) overrides the default. Lets `lune dev`
    # propagate --debug into the spawned user binary, and lets standalone Lune
    # apps crank up logging without code changes.
    level = case ENV["LUNE_LOG"]?.try(&.downcase)
            when "debug", "trace" then Log::Severity::Debug
            when "warn"           then Log::Severity::Warn
            when "error"          then Log::Severity::Error
            else                       Log::Severity::Info
            end
    backend = Log::IOBackend.new(STDERR, dispatcher: :sync)
    Log.setup("lune", level, backend)
    logger = Log.for("lune")
    logger.level = level
    logger
  end

  def self.enable_standard_logging : Nil
    logger.level = Log::Severity::Info
  end

  def self.enable_debug_logging : Nil
    logger.level = Log::Severity::Debug
  end

  @@config = LogConfig.new

  def self.config : LogConfig
    @@config
  end

  def self.configure(&block : LogConfig -> Nil) : Nil
    block.call(@@config)
  end

  def self.logger : Log
    @@config.logger
  end

  def self.logger=(logger : Log) : Log
    @@config.logger = logger
  end
end
