module Lune
  module Capabilities
    class FileDrop < Lune::Capability
      include Capability::WebviewInject

      DESCRIPTOR = Descriptor.new(id: :file_drop, label: "FileDrop", deps: [:event_bus])

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @options : Lune::Options::Drop = Lune::Options::Drop.new

      def setup(ctx : SetupCtx) : Nil
        @options = ctx.options.drop
      end

      def configured? : Bool
        !@options.zone.empty? || !@options.on_drop.nil? || @options.disable_webview_drop
      end

      def init_webview(wv : Webview::Webview, handle : Pointer(Void), app : Lune::App) : Nil
        init_webview(WebviewCtx.new(wv, handle, app, Set(Symbol).new))
      end

      def init_webview(ctx : WebviewCtx) : Nil
        drop = @options
        wv = ctx.wv
        handle = ctx.handle
        app = ctx.app

        Native::Window.disable_webview_drop(handle)

        user_callback = drop.on_drop
        use_drop_zones = !drop.zone.empty?

        on_pos = ->(x : Int32, y : Int32) { nil }
        drag_pos_fn : String? = nil

        bm = BRIDGE_MARKER

        {% if flag?(:darwin) %}
          drag_pos_fn = use_drop_zones ? "window.#{bm}.dragPos" : nil
        {% else %}
          if use_drop_zones
            on_pos = ->(x : Int32, y : Int32) {
              wv.dispatch { wv.eval("window.#{bm}.dragPos(#{x},#{y})") }
            }
          end
        {% end %}

        on_drop : (Int32, Int32, Array(String)) -> Nil = use_drop_zones ? drop_with_zones(wv, user_callback, bm) : drop_global(wv, app, user_callback, bm)

        Native::Window.setup_file_drop(handle, on_drop, on_pos, drag_pos_fn)

        drop_prop = use_drop_zones ? drop.zone : nil
        drop_val = use_drop_zones ? drop.value : nil
        wv.init(js_init(drop_prop, drop_val, bm))
      end

      def js_helpers : String
        bm = BRIDGE_MARKER
        <<-JS
          on(cb)  { window.#{bm}.on("file_drop", function(data) { cb(data.x, data.y, data.paths); }, -1); },
          off()   { window.#{bm}.off("file_drop"); },
        JS
      end

      def dts_helpers : String
        <<-DTS
          on(cb: (x: number, y: number, paths: string[]) => void): void;
          off(): void;
        DTS
      end

      private def drop_with_zones(wv : Webview::Webview, user_callback : ((Int32, Int32, Array(String)) -> Nil)?, bm : String) : (Int32, Int32, Array(String)) -> Nil
        ->(x : Int32, y : Int32, paths : Array(String)) {
          user_callback.try(&.call(x, y, paths))
          paths_json = paths.to_json
          wv.dispatch { wv.eval("window.#{bm}.dropCheck(#{x},#{y},#{paths_json.inspect})") }
        }
      end

      private def drop_global(wv : Webview::Webview, app : Lune::App, user_callback : ((Int32, Int32, Array(String)) -> Nil)?, bm : String) : (Int32, Int32, Array(String)) -> Nil
        ->(x : Int32, y : Int32, paths : Array(String)) {
          user_callback.try(&.call(x, y, paths))
          app.emit("file_drop", {"x" => x, "y" => y, "paths" => paths})
        }
      end

      private def js_init(css_prop : String?, css_val : String?, bm : String) : String
        drop_zone = ""
        if css_prop && css_val
          drop_zone = <<-JS
            window.#{bm} = window.#{bm} || {};
            var _lune_dz_prop = #{css_prop.inspect};
            var _lune_dz_val  = #{css_val.inspect};
            var _lune_dz_active = null;
            window.#{bm}.dragPos = function(x, y) {
              if (_lune_dz_active) {
                _lune_dz_active.classList.remove('lune-drop-target-active');
                _lune_dz_active = null;
              }
              if (x < 0) return;
              var el = document.elementFromPoint(x, y);
              while (el) {
                if (el.style && el.style.getPropertyValue(_lune_dz_prop).trim() === _lune_dz_val) {
                  _lune_dz_active = el;
                  el.classList.add('lune-drop-target-active');
                  return;
                }
                el = el.parentElement;
              }
            };
            window.#{bm}.dropCheck = function(x, y, pathsJson) {
              if (_lune_dz_active) {
                _lune_dz_active.classList.remove('lune-drop-target-active');
                _lune_dz_active = null;
                window.#{bm}.crystalEmit("file_drop", { x: x, y: y, paths: JSON.parse(pathsJson) });
              }
            };
          JS
        end
        <<-JS
        (function(){
          #{drop_zone}
          document.addEventListener('dragover', function(e){ e.preventDefault(); }, false);
          document.addEventListener('drop',     function(e){ e.preventDefault(); }, false);
        })();
        JS
      end
    end
  end
end
