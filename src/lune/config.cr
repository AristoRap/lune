require "yaml"

module Lune
  struct ConfigPlugins
    include YAML::Serializable

    getter enabled : Array(String)? = nil
    getter disabled : Array(String)? = nil

    def initialize(@enabled : Array(String)? = nil, @disabled : Array(String)? = nil); end
  end

  struct Config
    include YAML::Serializable

    getter window : Window = Window.new

    @[YAML::Field(key: "plugins")]
    @yaml_plugins : ConfigPlugins? = nil

    # Deprecated key; still parsed for one minor release. Migrate to `plugins:`.
    @[YAML::Field(key: "capabilities")]
    @yaml_capabilities : ConfigPlugins? = nil

    @[YAML::Field(ignore: true)]
    getter plugins : ConfigPlugins = ConfigPlugins.new

    def initialize; end

    protected def after_initialize
      if @yaml_capabilities && !@yaml_plugins
        Lune.logger.warn { "lune.yml: `capabilities:` is deprecated, rename to `plugins:`" }
      end
      @plugins = @yaml_plugins || @yaml_capabilities || ConfigPlugins.new
    end

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
