require "json"

module Lune
  module WindowState
    def self.path(app_name : String) : String
      base =
        {% if flag?(:darwin) %}
          Path.home.join("Library", "Application Support", app_name).to_s
        {% elsif flag?(:win32) %}
          File.join(ENV.fetch("APPDATA", Path.home.to_s), app_name)
        {% else %}
          File.join(ENV.fetch("XDG_CONFIG_HOME", Path.home.join(".config").to_s), app_name)
        {% end %}
      File.join(base, "window.json")
    end

    def self.load(app_name : String) : NamedTuple(x: Int32, y: Int32, width: Int32, height: Int32)?
      load_from(path(app_name))
    end

    def self.load_from(file_path : String) : NamedTuple(x: Int32, y: Int32, width: Int32, height: Int32)?
      return nil unless File.exists?(file_path)
      data = JSON.parse(File.read(file_path))
      {x: data["x"].as_i, y: data["y"].as_i, width: data["width"].as_i, height: data["height"].as_i}
    rescue
      nil
    end

    def self.save(app_name : String, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
      save_to(path(app_name), x, y, width, height)
    end

    def self.save_to(file_path : String, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
      Dir.mkdir_p(File.dirname(file_path))
      File.write(file_path, {x: x, y: y, width: width, height: height}.to_json)
    end

    def self.app_name(title : String) : String
      n = title.downcase.gsub(/\s+/, "-").gsub(/[^a-z0-9\-]/, "")
      n.empty? ? "lune" : n
    end
  end
end
