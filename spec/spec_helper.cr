require "spec"
require "../src/lune"

Spec.before_each do
  Lune.logger = Lune.default_logger.tap do |logger|
    logger.level = Log::Severity::None
  end
end
