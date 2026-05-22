module Lune
  module Capabilities
    class ContextMenu < Lune::Capability
      include Lune::Bindable

      DESCRIPTOR = Descriptor.new(id: :context_menu, label: "ContextMenu", deps: [:events])

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @handle : Void* = Pointer(Void).null

      def setup(ctx : SetupCtx) : Nil
        @handle = ctx.handle
      end

      @[Lune::Bind]
      @[Lune::BindOverride(arg_names: ["x", "y", "itemsJson"])]
      def show(x : Float64, y : Float64, items_json : String) : Nil
        Lune::Native::Menu.show_context_menu(@handle, x.to_f32, y.to_f32, items_json) do |id|
          @app.events.emit("context_menu", {"id" => id})
        end
      end

      def init_js : String?
        bm = BRIDGE_MARKER
        ctx_show_id = "#{bm}.context_menu.show"
        <<-JS
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
          set(items)      { window.#{bm}.setContextMenu(items || []); },
          clear()         { window.#{bm}.setContextMenu([]); },
          onSelect(cb)    { window.#{bm}.on("context_menu", function(data) { cb(data.id); }, -1); },
        JS
      end

      def dts_helpers : String
        <<-DTS
          set(items: ContextMenuItem[]): void;
          clear(): void;
          onSelect(cb: (id: string) => void): void;
        DTS
      end
    end
  end
end
