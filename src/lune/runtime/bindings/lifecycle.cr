require "json"

module Lune
  module Runtime
    module Bindings
      class Lifecycle
        include Lune::Installable

        DEFAULT_OPEN_URL = ->(url : String) {
          {% if flag?(:darwin) %}
            Process.run("open", [url])
          {% else %}
            Process.run("xdg-open", [url])
          {% end %}
          nil
        }

        def initialize(
          @on_quit : -> Nil,
          @on_open_url : String -> Nil = DEFAULT_OPEN_URL,
          @debug : Bool = false
        )
        end

        def install(app : Lune::App)
          quit(app)
          open_url(app)
          environment(app)
        end

        private def quit(app : Lune::App)
          app.bind(
            namespace: "runtime",
            method: "__lune.quit",
            args: [] of String,
            return_type: "Nil",
            async: false,
            runtime: true
          ) do |_args|
            @on_quit.call
            JSON::Any.new(nil)
          end
        end

        private def open_url(app : Lune::App)
          app.bind(
            namespace: "runtime",
            method: "__lune.openURL",
            args: ["String"],
            return_type: "Nil",
            async: true,
            runtime: true
          ) do |args|
            @on_open_url.call(args[0].as_s)
            JSON::Any.new(nil)
          end
        end

        private def environment(app : Lune::App)
          app.bind(
            namespace: "runtime",
            method: "__lune.environment",
            args: [] of String,
            return_type: "JSON",
            async: false,
            runtime: true
          ) do |_args|
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

            JSON.parse({os: os, arch: arch, debug: @debug}.to_json)
          end
        end
      end
    end
  end
end
