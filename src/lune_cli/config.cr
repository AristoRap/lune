require "yaml"

module LuneCLI
  struct Config
    include YAML::Serializable

    getter name : String? = nil
    getter app_entry : String = "src/main.cr"
    getter icon : String? = nil
    getter frontend : Frontend = Frontend.new

    def initialize; end

    def self.load(path : String = "lune.yml") : Config
      return new unless File.exists?(path)
      from_yaml(File.read(path))
    rescue ex : YAML::ParseException
      Lune.logger.warn { "Could not parse #{path}: #{ex.message}" }
      new
    end

    struct Frontend
      include YAML::Serializable

      getter dir : String = Lune::DEFAULT_FRONTEND_DIR
      getter install : String? = nil
      getter build : String? = nil
      getter dev : Dev = Dev.new

      def initialize; end

      struct Dev
        include YAML::Serializable

        getter cmd : String? = nil
        getter url : String = "http://localhost:5173"

        def initialize; end
      end
    end
  end
end
