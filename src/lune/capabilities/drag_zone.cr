module Lune
  module Capabilities
    class DragZone < Lune::Capability
      def initialize(@css_var : String, @css_val : String)
      end

      def name : String
        "drag_zone"
      end

      def core? : Bool
        true
      end

      def configured? : Bool
        !@css_var.empty?
      end

      def init_webview(wv : Webview::Webview, handle : Pointer(Void), app : Lune::App) : Nil
        return if @css_var.empty?

        {% if flag?(:darwin) %}
          Native::Window.setup_drag_monitor

          css_var = @css_var
          css_val = @css_val
          start_drag_key = "#{BRIDGE_MARKER}.startDrag"

          wv.bind(start_drag_key, Webview::JSProc.new { |_args|
            Native::Window.start_window_drag(handle)
            JSON::Any.new(nil)
          })

          wv.init(<<-JS)
          (function(){
            document.addEventListener('mousedown', function(e) {
              var el = e.target;
              while (el) {
                if (el.style && el.style.getPropertyValue(#{css_var.inspect}).trim() === #{css_val.inspect}) {
                  window[#{start_drag_key.inspect}]();
                  return;
                }
                el = el.parentElement;
              }
            }, true);
          })();
          JS
        {% end %}
      end
    end
  end
end
