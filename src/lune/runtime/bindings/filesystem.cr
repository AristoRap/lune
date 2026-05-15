require "json"

module Lune
  module Runtime
    module Bindings
      class Filesystem
        include Lune::Installable

        def install(app : Lune::App)
          home_dir(app)
          temp_dir(app)
          downloads_dir(app)
          app_data_dir(app)
        end

        private def home_dir(app : Lune::App)
          app.register(Lune::RuntimeBinding.new(
            namespace: "runtime",
            method: "__lune.homeDir",
            args: [] of String,
            return_type: "String",
            callback: ->(_args : Array(JSON::Any)) { JSON::Any.new(Path.home.to_s) },
          ))
        end

        private def temp_dir(app : Lune::App)
          app.register(Lune::RuntimeBinding.new(
            namespace: "runtime",
            method: "__lune.tempDir",
            args: [] of String,
            return_type: "String",
            callback: ->(_args : Array(JSON::Any)) { JSON::Any.new(Dir.tempdir) },
          ))
        end

        private def downloads_dir(app : Lune::App)
          app.register(Lune::RuntimeBinding.new(
            namespace: "runtime",
            method: "__lune.downloadsDir",
            args: [] of String,
            return_type: "String",
            callback: ->(_args : Array(JSON::Any)) { JSON::Any.new(Path.home.join("Downloads").to_s) },
          ))
        end

        private def app_data_dir(app : Lune::App)
          app.register(Lune::RuntimeBinding.new(
            namespace: "runtime",
            method: "__lune.appDataDir",
            args: [] of String,
            return_type: "String",
            callback: ->(_args : Array(JSON::Any)) {
              path =
                {% if flag?(:darwin) %}
                  Path.home.join("Library", "Application Support").to_s
                {% elsif flag?(:win32) %}
                  ENV["APPDATA"]? || Path.home.to_s
                {% else %}
                  ENV["XDG_DATA_HOME"]? || Path.home.join(".local", "share").to_s
                {% end %}
              JSON::Any.new(path)
            },
          ))
        end
      end
    end
  end
end
