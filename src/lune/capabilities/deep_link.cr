module Lune
  module Capabilities
    class DeepLink < Lune::Capability
      DESCRIPTOR = Descriptor.new(id: :deep_link, label: "DeepLink", deps: [:events])

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @app_title : String = "lune"

      def setup(ctx : SetupCtx) : Nil
        @app_title = ctx.options.title
      end

      def install(app : Lune::App) : Nil
        url_from_argv = ARGV.find { |arg| arg.includes?("://") }

        # Linux warm-start: if a primary instance is already running, send
        # the URL over its Unix-socket and exit instead of opening a new
        # window. macOS doesn't need this (NSApp is single-instance by
        # default); Windows would want named pipes — deferred to v0.12.0.
        {% if flag?(:linux) %}
          if url_from_argv && Lune::DeepLinkIPC.forward(url_from_argv, @app_title)
            Lune.logger.info { "DeepLink: forwarded #{url_from_argv} to running instance" }
            Process.exit(0)
          end

          # We're the primary — listen for forwards from future invocations.
          Lune::DeepLinkIPC.listen(@app_title) do |incoming|
            app.events.emit("deep_link", {"url" => incoming})
          end
        {% end %}

        {% if flag?(:lune_native_test_mock) || flag?(:darwin) %}
          Native::DeepLink.install do |url|
            app.events.emit("deep_link", {"url" => url})
          end
        {% elsif flag?(:linux) || flag?(:win32) %}
          # Cold-start delivery: OS launches the app with a URL on the
          # command line (after `myapp://` is registered with the desktop
          # or registry); the URL lands in ARGV. Same path on Linux and
          # Windows.
          if url = url_from_argv
            app.events.emit("deep_link", {"url" => url})
          end
        {% end %}
      end

      def js_helpers : String
        bm = BRIDGE_MARKER
        <<-JS
          on(cb)  { window.#{bm}.on("deep_link", function(data) { cb(data.url); }, -1); },
          off()   { window.#{bm}.off("deep_link"); },
        JS
      end

      def dts_helpers : String
        <<-DTS
          on(cb: (url: string) => void): void;
          off(): void;
        DTS
      end
    end
  end
end
