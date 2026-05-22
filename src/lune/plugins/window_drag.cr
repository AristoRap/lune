module Lune
  module Plugins
    # macOS-only: lets the user tag DOM elements (via a CSS custom property,
    # e.g. `style="--lune-drag-zone: yes"`) such that mousedown on them drags
    # the OS window. Configure via `opts.window_drag.zone` /
    # `opts.window_drag.value`.
    class WindowDrag < Lune::Plugin
      include Lune::Bindable
      include Plugin::WebviewInject

      DESCRIPTOR = Descriptor.new(id: :window_drag, label: "WindowDrag", platforms: [:darwin])

      def descriptor : Descriptor
        DESCRIPTOR
      end

      config do
        # CSS custom property name that marks an element as a window drag
        # handle. When non-empty, any element with this property set to a
        # truthy value can be used to drag the window. Example:
        # `"--lune-draggable"`. The presence of the property is what
        # activates — the value itself is ignored beyond being non-empty.
        property zone : String = ""
      end

      @handle : Pointer(Void) = Pointer(Void).null

      def setup(ctx : SetupCtx) : Nil
        @handle = ctx.handle
      end

      def init_webview(ctx : WebviewCtx) : Nil
        return if @config.zone.empty?
        {% if flag?(:darwin) %}
          Native::Window.setup_drag_monitor
        {% end %}
      end

      # Called from init_js when mousedown lands on a drag-zone element.
      # macOS-only; the platform gate at descriptor.platforms keeps this
      # method from being invoked elsewhere.
      @[Lune::Bind]
      def start : Nil
        {% if flag?(:darwin) %}
          Native::Window.start_window_drag(@handle)
        {% end %}
      end

      def init_js : String?
        return nil if @config.zone.empty?
        {% if flag?(:darwin) %}
          start_key = "#{binding_namespace.gsub("::", ".")}.start"
          <<-JS
          (function(){
            document.addEventListener('mousedown', function(e) {
              var el = e.target;
              while (el) {
                if (el.style && el.style.getPropertyValue(#{@config.zone.inspect}).trim() !== "") {
                  window[#{start_key.inspect}]();
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
