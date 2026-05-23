require "yaml"

module LuneCLI
  struct Config
    include YAML::Serializable

    property name : String? = nil
    property app_entry : String = "src/main.cr"
    property icon : String? = nil
    property url_schemes : Array(String) = [] of String
    property frontend : Frontend = Frontend.new
    property mac : Mac = Mac.new

    def initialize; end

    def self.load(path : String = "lune.yml") : Config
      return new unless File.exists?(path)
      from_yaml(File.read(path))
    rescue ex : YAML::ParseException
      Lune.logger.warn { "Could not parse #{path}: #{ex.message}" }
      new
    end

    struct Mac
      include YAML::Serializable

      getter sign : String? = nil
      getter bundle_id : String? = nil
      getter entitlements : String? = nil
      getter notarize : Bool = false

      def initialize; end
    end

    struct Frontend
      include YAML::Serializable

      property dir : String = Lune::DEFAULT_FRONTEND_DIR
      property install : String? = nil
      property build : String? = nil
      property dev : Dev = Dev.new

      def initialize; end

      struct Dev
        include YAML::Serializable

        property cmd : String? = nil
        property url : String = "http://localhost:5173"

        def initialize; end
      end
    end
  end
end
