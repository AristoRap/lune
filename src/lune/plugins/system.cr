module Lune
  module Plugins
    class System < Lune::Plugin
      include Lune::Bindable

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
        @on_quit : -> Nil = -> { },
        @on_open_url : String -> Nil = DEFAULT_OPEN_URL,
        @devtools : Bool = false,
      )
      end

      # Runtime deps arrive via SetupCtx so the plugin can be default-
      # constructed from `Lune.use(System.new)`. `on_quit` defaults to an
      # empty proc so direct construction in specs works without going
      # through `Registry`.
      def setup(ctx : SetupCtx) : Nil
        @on_quit = ctx.on_quit
        @devtools = ctx.options.devtools
      end

      @[Lune::Bind]
      def quit : Nil
        @on_quit.call
      end

      @[Lune::Bind(async: true)]
      def open_url(url : String) : Nil
        @on_open_url.call(url)
      end

      @[Lune::Bind]
      @[Lune::BindOverride(ts_return_type: "Promise<LuneEnvironment>")]
      def environment : NamedTuple(os: String, arch: String, devtools: Bool)
        os = {% if flag?(:darwin) %}
          "darwin"
        {% elsif flag?(:linux) %}
          "linux"
        {% elsif flag?(:win32) %}
          "windows"
        {% else %}
          "unknown"
        {% end %}
        arch = {% if flag?(:aarch64) %}
          "arm64"
        {% else %}
          "x86_64"
        {% end %}
        {os: os, arch: arch, devtools: @devtools}
      end
    end
  end
end
