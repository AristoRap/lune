module Lune
  module Capabilities
    class DeepLink < Lune::Capability
      def name : String
        "deep_link"
      end


      def install(app : Lune::App)
        {% if flag?(:lune_native_test_mock) || flag?(:darwin) %}
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
