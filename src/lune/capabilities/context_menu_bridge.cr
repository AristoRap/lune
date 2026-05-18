module Lune
  module Capabilities
    class ContextMenuBridge < Lune::Capability
      def name : String
        "context_menu_bridge"
      end

      def core? : Bool
        true
      end

      def init_webview(wv : Webview::Webview, handle : Pointer(Void), app : Lune::App) : Nil
        bm = BRIDGE_MARKER
        # Bridge ID: "__lune.context_menu.show"
        ctx_show_id = "#{bm}.context_menu.show"
        wv.init(<<-JS)
        (function(){
          window.#{bm} = window.#{bm} || {};
          var _ctx_items = null;
          window.#{bm}.setContextMenu = function(items) {
            _ctx_items = (items && items.length) ? items : null;
          };
          document.addEventListener('contextmenu', function(e) {
            if (!_ctx_items) return;
            e.preventDefault();
            window[#{ctx_show_id.inspect}](e.clientX, e.clientY, JSON.stringify(_ctx_items));
          });
        })();
        JS
      end

      def js_helpers : String
        bm = BRIDGE_MARKER
        <<-JS
          setContextMenu(items)  { window.#{bm}.setContextMenu(items || []); },
          clearContextMenu()     { window.#{bm}.setContextMenu([]); },
          onContextMenu(cb)      { window.#{bm}.on("context_menu", function(data) { cb(data.id); }, -1); },
        JS
      end

      def dts_helpers : String
        <<-DTS
          setContextMenu(items: ContextMenuItem[]): void;
          clearContextMenu(): void;
          onContextMenu(cb: (id: string) => void): void;
        DTS
      end
    end
  end
end
