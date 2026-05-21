module Lune
  module Capabilities
    # macOS-only: lets the user tag DOM elements (via a CSS custom property,
    # e.g. `style="--lune-drag-zone: yes"`) such that mousedown on them drags
    # the OS window. Configure via `opts.drag.zone` / `opts.drag.value`.
    class WindowDrag < Lune::Capability
      include Capability::WebviewInject

      DESCRIPTOR = Descriptor.new(id: :window_drag, label: "WindowDrag", platforms: [:darwin])

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @css_var = ""
      @css_val = ""
      @handle : Pointer(Void) = Pointer(Void).null

      def setup(ctx : SetupCtx) : Nil
        @css_var = ctx.options.drag.zone
        @css_val = ctx.options.drag.value
        @handle = ctx.handle
      end

      def init_webview(ctx : WebviewCtx) : Nil
        return if @css_var.empty?

        {% if flag?(:darwin) %}
          handle = @handle
          start_drag_key = "#{Lune::Capability::BRIDGE_MARKER}.startDrag"

          Native::Window.setup_drag_monitor

          ctx.wv.bind(start_drag_key, Webview::JSProc.new { |_args|
            Native::Window.start_window_drag(handle)
            JSON::Any.new(nil)
          })

          ctx.wv.init(<<-JS)
          (function(){
            document.addEventListener('mousedown', function(e) {
              var el = e.target;
              while (el) {
                if (el.style && el.style.getPropertyValue(#{@css_var.inspect}).trim() === #{@css_val.inspect}) {
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
