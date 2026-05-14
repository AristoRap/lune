module Lune
  module PathBindings
    def self.build : Array(BindingDef)
      [
        BindingDef.new(
          "__lune.homeDir",
          "runtime",
          [] of String,
          "String",
          ->(_args : Array(JSON::Any)) {
            JSON::Any.new(Path.home.to_s)
          },
          internal: true,
          async: false
        ),

        BindingDef.new(
          "__lune.tempDir",
          "runtime",
          [] of String,
          "String",
          ->(_args : Array(JSON::Any)) {
            JSON::Any.new(Dir.tempdir)
          },
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
