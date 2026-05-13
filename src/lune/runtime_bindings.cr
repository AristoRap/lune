module Lune
  module RuntimeBindings
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
      ]
    end
  end
end
