require "yaml"

module LuneCLI
  struct Config
    include YAML::Serializable

    getter name : String? = nil
    getter app_entry : String? = nil
    getter frontend_dir : String? = nil
    getter dev_cmd : String? = nil
    getter build_cmd : String? = nil
    getter dev_url : String? = nil

    def initialize; end

    def self.load(path : String = "lune.yml") : Config
      return new unless File.exists?(path)
      from_yaml(File.read(path))
    rescue ex : YAML::ParseException
      Lune.logger.warn { "Could not parse #{path}: #{ex.message}" }
      new
    end
  end
end
