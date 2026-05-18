require "log"

module Lune
  class LogConfig
    property logger : Log

    def initialize(@logger : Log = Lune.default_logger)
    end
  end

  def self.default_logger : Log
    backend = Log::IOBackend.new(STDERR, dispatcher: :sync)
    Log.setup("lune", :info, backend)
    logger = Log.for("lune")
    logger.level = Log::Severity::Info
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
