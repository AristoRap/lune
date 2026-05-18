module Lune
  module Capabilities
    class System < Lune::Capability
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
        @debug : Bool = false,
      )
      end

      def name : String
        "system"
      end

      def core? : Bool
        false
      end

      def install(app : Lune::App)
        on_quit = @on_quit
        app.register(Definition.new(
          name: "#{name}.quit",
          args: [] of String,
          return_type: "Nil",
          callback: ->(_args : Array(JSON::Any)) { on_quit.call; JSON::Any.new(nil) },
        ).binding(binding_namespace))

        on_open_url = @on_open_url
        app.register(Definition.new(
          name: "#{name}.open_url",
          args: ["String"],
          return_type: "Nil",
          async: true,
          arg_names: ["url"],
          callback: ->(args : Array(JSON::Any)) { on_open_url.call(args[0].as_s); JSON::Any.new(nil) },
        ).binding(binding_namespace))

        debug = @debug
        app.register(Definition.new(
          name: "#{name}.environment",
          args: [] of String,
          return_type: "JSON",
          ts_return_type: "Promise<LuneEnvironment>",
          callback: ->(_args : Array(JSON::Any)) {
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
        ).binding(binding_namespace))
      end
    end
  end
end
