module Lune
  module Plugins
    # macOS-only: lets the user tag DOM elements (via a CSS custom property,
    # e.g. `style="--lune-drag-zone: yes"`) such that mousedown on them drags
    # the OS window. Configure via `opts.drag.zone` / `opts.drag.value`.
    class WindowDrag < Lune::Plugin
      include Plugin::WebviewInject

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
          Native::Window.setup_drag_monitor
          ctx.wv.bind("#{Lune::Plugin::BRIDGE_MARKER}.startDrag", Webview::JSProc.new { |_args|
            Native::Window.start_window_drag(handle)
            JSON::Any.new(nil)
          })
        {% end %}
      end

      def init_js : String?
        return nil if @css_var.empty?
        {% if flag?(:darwin) %}
          start_drag_key = "#{Lune::Plugin::BRIDGE_MARKER}.startDrag"
          <<-JS
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
        {% else %}
          nil
        {% end %}
      end
    end
  end
end
