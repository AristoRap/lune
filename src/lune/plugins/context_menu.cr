module Lune
  module Plugins
    class ContextMenu < Lune::Plugin
      include Lune::Bindable

      DESCRIPTOR = Descriptor.new(id: :context_menu, label: "ContextMenu", deps: [:events])

      def descriptor : Descriptor
        DESCRIPTOR
      end

      config do
        # When true, suppresses the browser's default right-click menu. Replaces
        # the standalone `ContextMenuBlocker` plugin and the top-level
        # `opts.disable_context_menu` flag — both removed.
        property block_default : Bool = false
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
        show_key = "#{binding_namespace.gsub("::", ".")}.show"
        block_line = @config.block_default ? "document.addEventListener('contextmenu',function(e){e.preventDefault();});" : ""
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
            window[#{show_key.inspect}](e.clientX, e.clientY, JSON.stringify(_ctx_items));
          });
          #{block_line}
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
