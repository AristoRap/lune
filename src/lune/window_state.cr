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
    rescue ex : JSON::ParseException | TypeCastError | File::Error | IO::Error
      Lune.logger.warn { "WindowState: failed to load #{file_path} — #{ex.message}" }
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

    {% if flag?(:win32) %}
      # On Windows the HWND is destroyed by the time wv.run returns, so the
      # usual "GetWindowRect on shutdown" path saves all-zeros. Instead, poll
      # the live window every 500 ms while it's alive and persist on each
      # tick. IsWindow gives us a clean self-stop signal — once webview_destroy
      # has fired the handle is no longer a window and the loop exits.
      def self.start_tracker(app_name : String, handle : Void*) : Nil
        ::spawn(name: "lune-window-state-tracker") do
          loop do
            sleep 500.milliseconds
            break unless Lune::Native::Window.alive?(handle)
            x, y, width, height = Lune::Native::Window.get_frame(handle)
            # During minimize x/y/width/height are bogus (huge negatives), skip
            # those so we don't persist a minimized frame as the restore target.
            next if width <= 0 || height <= 0 || x < -10000 || y < -10000
            save(app_name, x, y, width, height)
          rescue ex
            Lune.logger.debug { "WindowState: tracker tick failed — #{ex.message}" }
          end
        end
      end
    {% end %}
  end
end
