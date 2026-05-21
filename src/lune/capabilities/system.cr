module Lune
  module Capabilities
    class System < Lune::Capability
      include Capability::BindPhase

      DESCRIPTOR = Descriptor.new(id: :system, label: "System")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      DEFAULT_OPEN_URL = ->(url : String) {
        {% if flag?(:darwin) %}
          Process.run("open", [url])
        {% elsif flag?(:win32) %}
          # `start` is a cmd builtin; the empty "" is the window-title placeholder
          # that `start` consumes if the first arg looks like a path.
          Process.run("cmd", ["/c", "start", "", url])
        {% else %}
          Process.run("xdg-open", [url])
        {% end %}
        nil
      }

      def initialize(
        @on_quit : -> Nil,
        @on_open_url : String -> Nil = DEFAULT_OPEN_URL,
        @devtools : Bool = false,
      )
      end

      def setup(ctx : SetupCtx) : Nil
        @devtools = ctx.options.devtools
      end

      def install(ctx : BindCtx) : Nil
        on_quit = @on_quit
        ctx.define("quit") do |_args|
          on_quit.call
          JSON::Any.new(nil)
        end

        on_open_url = @on_open_url
        ctx.define("open_url",
          args: ["String"],
          async: true,
          arg_names: ["url"],
        ) do |args|
          on_open_url.call(args[0].as_s)
          JSON::Any.new(nil)
        end

        devtools = @devtools
        ctx.define("environment",
          return_type: "JSON",
          ts_return_type: "Promise<LuneEnvironment>",
        ) do |_args|
          os =
            {% if flag?(:darwin) %}
              "darwin"
            {% elsif flag?(:linux) %}
              "linux"
            {% elsif flag?(:win32) %}
              "windows"
            {% else %}
              "unknown"
            {% end %}
          arch =
            {% if flag?(:aarch64) %}
              "arm64"
            {% else %}
              "x86_64"
            {% end %}
          JSON.parse({os: os, arch: arch, devtools: devtools}.to_json)
        end
      end
    end
  end
end
