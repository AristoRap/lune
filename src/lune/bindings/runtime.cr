module Lune
  module Bindings
    module Runtime
      DEFAULT_OPEN_URL = ->(url : String) {
        {% if flag?(:darwin) %}
          Process.run("open", [url])
        {% else %}
          Process.run("xdg-open", [url])
        {% end %}
        nil
      }

      def self.build(
        on_quit : -> Nil,
        on_open_url : String -> Nil = DEFAULT_OPEN_URL,
        debug : Bool = false,
      ) : Array(BindingDef)
        [
          BindingDef.new(
            "__lune.quit",
            "runtime",
            [] of String,
            "Nil",
            ->(args : Array(JSON::Any)) {
              on_quit.call
              JSON::Any.new(nil)
            },
            internal: true,
            async: false
          ),

          BindingDef.new(
            "__lune.openURL",
            "runtime",
            ["String"],
            "Nil",
            ->(args : Array(JSON::Any)) {
              on_open_url.call(args[0].as_s)
              JSON::Any.new(nil)
            },
            internal: true,
            async: true
          ),

          BindingDef.new(
            "__lune.environment",
            "runtime",
            [] of String,
            "JSON",
            ->(_args : Array(JSON::Any)) {
              os =
                {% if flag?(:darwin) %}
                  "darwin"
                {% elsif flag?(:linux) %}
                  "linux"
                {% else %}
                  "windows"
                {% end %}

              arch =
                {% if flag?(:aarch64) %}
                  "arm64"
                {% else %}
                  "x86_64"
                {% end %}

              JSON.parse({os: os, arch: arch, debug: debug}.to_json)
            },
            internal: true,
            async: false
          ),

          BindingDef.new(
            "__lune.homeDir",
            "runtime",
            [] of String,
            "String",
            ->(_args : Array(JSON::Any)) { JSON::Any.new(Path.home.to_s) },
            internal: true,
            async: false
          ),

          BindingDef.new(
            "__lune.tempDir",
            "runtime",
            [] of String,
            "String",
            ->(_args : Array(JSON::Any)) { JSON::Any.new(Dir.tempdir) },
            internal: true,
            async: false
          ),

          BindingDef.new(
            "__lune.downloadsDir",
            "runtime",
            [] of String,
            "String",
            ->(_args : Array(JSON::Any)) {
              JSON::Any.new(Path.home.join("Downloads").to_s)
            },
            internal: true,
            async: false
          ),

          BindingDef.new(
            "__lune.appDataDir",
            "runtime",
            [] of String,
            "String",
            ->(_args : Array(JSON::Any)) {
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
            internal: true,
            async: false
          ),
        ]
      end
    end
  end
end
