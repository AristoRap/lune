module Lune
  module Plugins
    # The Window plugin owns runtime window controls (minimize, maximize,
    # center, hide, show, set_title, set_size) and the optional CSS-driven
    # window-drag listener.
    #
    # Drag is configured via `opts.window.drag_zone = "--lune-draggable"`.
    # When empty (the default), no drag listener is injected and the
    # `start_drag` binding is unused. The native drag itself is macOS-only;
    # the listener and binding are compiled out on non-darwin via
    # `{% if flag?(:darwin) %}` so non-darwin builds skip both the
    # mousedown injection and the runtime binding.
    class Window < Lune::Plugin
      include Lune::Bindable
      include Plugin::WebviewInject

      DESCRIPTOR = Descriptor.new(id: :window, label: "Window")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      config do
        # CSS custom property name that marks an element as a window drag
        # handle. Any non-empty inline value on the property activates the
        # drag — `style="--lune-draggable: true"` is the idiomatic shape.
        # Leave empty to skip drag entirely (default).
        property drag_zone : String = ""
      end

      @handle : Void* = Pointer(Void).null

      def setup(ctx : SetupCtx) : Nil
        @handle = ctx.handle
      end

      def init_webview(ctx : WebviewCtx) : Nil
        return if @config.drag_zone.empty?
        {% if flag?(:darwin) %}
          Native::Window.setup_drag_monitor
        {% end %}
      end

      def init_js : String?
        return nil if @config.drag_zone.empty?
        {% if flag?(:darwin) %}
          start_key = "#{binding_namespace.gsub("::", ".")}.start_drag"
          <<-JS
          (function(){
            document.addEventListener('mousedown', function(e) {
              var el = e.target;
              while (el) {
                if (el.style && el.style.getPropertyValue(#{@config.drag_zone.inspect}).trim() !== "") {
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

      @[Lune::Bind]
      def minimize : Nil
        Lune::Native::Window.minimize(@handle)
      end

      @[Lune::Bind]
      def maximize : Nil
        Lune::Native::Window.maximize(@handle)
      end

      @[Lune::Bind]
      def center : Nil
        Lune::Native::Window.center(@handle)
      end

      @[Lune::Bind]
      def hide : Nil
        Lune::Native::Window.hide(@handle)
      end

      @[Lune::Bind]
      def show : Nil
        Lune::Native::Window.show(@handle)
      end

      @[Lune::Bind]
      def set_title(title : String) : Nil
        Lune::Native::Window.set_title(@handle, title)
      end

      @[Lune::Bind]
      def set_size(width : Int32, height : Int32) : Nil
        Lune::Native::Window.set_size(@handle, width, height)
      end

      # Native window-drag start. macOS-only — defined inside an
      # `{% if flag?(:darwin) %}` block so the `@[Lune::Bind]` macro only
      # registers it on darwin, keeping the per-platform binding count
      # identical to before this plugin was merged with WindowDrag.
      {% if flag?(:darwin) %}
        @[Lune::Bind]
        def start_drag : Nil
          Lune::Native::Window.start_window_drag(@handle)
        end
      {% end %}
    end
  end
end
