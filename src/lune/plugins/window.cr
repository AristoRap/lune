module Lune
  module Plugins
    # The Window plugin owns runtime window controls (minimize, maximize,
    # center, hide, show, set_title, set_size) and the optional CSS-driven
    # window-drag listener.
    #
    # Drag is configured via `opts.window.drag_zone = "--lune-draggable"`.
    # When empty (the default), no drag listener is injected and the
    # `start_drag` binding is unused. Drag is implemented on macOS
    # (NSWindow performWindowDrag) and Windows (ReleaseCapture +
    # WM_NCLBUTTONDOWN/HTCAPTION); Linux still needs `_NET_WM_MOVERESIZE`.
    # The listener and binding are compiled out on Linux via
    # `{% if flag?(:darwin) || flag?(:win32) %}` so Linux builds skip both
    # the mousedown injection and the runtime binding.
    class Window < Lune::Plugin
      include Lune::Bindable
      include Plugin::WebviewInject

      DESCRIPTOR = Descriptor.new(id: :window, label: "Window")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      config do
        # CSS custom property name that marks an element as a window drag
        # handle. Non-empty inline values enable drag, except false, 0 and
        # no-drag, which exclude the element's entire subtree.
        # Leave empty to skip drag entirely (default).
        property drag_zone : String = ""

        # CSS selector for controls/regions that must retain pointer interaction.
        # Override for custom widgets; set empty to use only explicit no-drag markers.
        property drag_exclude : String = "a, button, input, select, textarea, label, summary, " \
                                         "[contenteditable]:not([contenteditable='false']), [tabindex], " \
                                         "[role='button'], [role='link'], [role='slider'], [role='checkbox'], " \
                                         "[role='switch'], [role='tab'], [role='menuitem'], [role='combobox'], " \
                                         "[draggable='true'], [data-lune-no-drag], dialog, svg, canvas"
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
        return if @config.drag_zone.empty?
        {% if flag?(:darwin) || flag?(:win32) %}
          # camelCased to match the binding's dispatch id (`Binding#id`
          # camelCases the method leaf), which is what the bridge binds.
          start_key = "#{binding_namespace.gsub("::", ".")}.startDrag"
          <<-JS
          (function(){
            document.addEventListener('mousedown', function(e) {
              if (e.defaultPrevented || e.button !== 0 || e.ctrlKey || e.metaKey || e.altKey || e.shiftKey) return;
              var path = e.composedPath();
              var excluded = #{@config.drag_exclude.inspect};
              var draggable = false;
              for (var i = 0; i < path.length; i++) {
                var el = path[i];
                if (!(el instanceof Element)) continue;
                if (excluded && el.matches(excluded)) return;
                var value = el.style ? el.style.getPropertyValue(#{@config.drag_zone.inspect}).trim().toLowerCase() : "";
                if (value === "false" || value === "0" || value === "no-drag") return;
                if (value !== "") draggable = true;
              }
              if (!draggable) return;
              // Scrollbar presses target the scroll container, not its content.
              var target = path[0];
              if (target instanceof HTMLElement) {
                var rect = target.getBoundingClientRect();
                var x = e.clientX - rect.left;
                var y = e.clientY - rect.top;
                if (target.scrollHeight > target.clientHeight && target.offsetWidth > target.clientWidth &&
                    (x < target.clientLeft || x >= target.clientLeft + target.clientWidth)) return;
                if (target.scrollWidth > target.clientWidth && target.offsetHeight > target.clientHeight &&
                    (y < target.clientTop || y >= target.clientTop + target.clientHeight)) return;
              }
              e.preventDefault();
              window[#{start_key.inspect}]();
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

      # Native window-drag start. macOS + Windows — Linux still no-ops.
      # Guarded so the `@[Lune::Bind]` macro only registers the binding on
      # platforms that actually drive a drag, keeping Linux's binding count
      # identical to before drag landed there.
      {% if flag?(:darwin) || flag?(:win32) %}
        @[Lune::Bind]
        def start_drag : Nil
          Lune::Native::Window.start_window_drag(@handle)
        end
      {% end %}
    end
  end
end
