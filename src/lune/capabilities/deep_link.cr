module Lune
  module Capabilities
    class DeepLink < Lune::Capability
      def name : String
        "deep_link"
      end

      def core? : Bool
        false
      end

      def install(app : Lune::App)
        {% if flag?(:darwin) %}
          Native::DeepLink.install do |url|
            app.emit("deep_link", {"url" => url})
          end
        {% elsif flag?(:linux) %}
          if url = ARGV.find { |arg| arg.includes?("://") }
            app.emit("deep_link", {"url" => url})
          end
        {% end %}
      end

      def js_helpers : String
        bm = BRIDGE_MARKER
        <<-JS
          onDeepLink(cb)  { window.#{bm}.on("deep_link", function(data) { cb(data.url); }, -1); },
          onDeepLinkOff() { window.#{bm}.off("deep_link"); },
        JS
      end

      def dts_helpers : String
        <<-DTS
          onDeepLink(cb: (url: string) => void): void;
          onDeepLinkOff(): void;
        DTS
      end
    end
  end
end
