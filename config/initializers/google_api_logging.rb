require "logger"
require "google/apis"

Google::Apis.logger = Logger.new($stdout, level: Logger::WARN)
