require "yaml"

module Lune
  struct ConfigCapabilities
    include YAML::Serializable

    @[YAML::Field(key: "include")]
    getter only : Array(String)? = nil

    getter exclude : Array(String)? = nil

    def initialize(@only : Array(String)? = nil, @exclude : Array(String)? = nil); end
  end

  struct Config
    include YAML::Serializable

    getter window : Window = Window.new
    getter capabilities : ConfigCapabilities = ConfigCapabilities.new

    def initialize; end

    def self.load(path : String = "lune.yml") : Config
      return new unless File.exists?(path)
      from_yaml(File.read(path))
    rescue YAML::ParseException
      new
    end

    struct Window
      include YAML::Serializable

      property title : String? = nil
      property width : Int32? = nil
      property height : Int32? = nil
      property min_width : Int32? = nil
      property min_height : Int32? = nil
      property max_width : Int32? = nil
      property max_height : Int32? = nil
      property resizable : Bool? = nil
      property devtools : Bool? = nil
      property remember_frame : Bool? = nil

      def initialize; end
    end
  end
end
