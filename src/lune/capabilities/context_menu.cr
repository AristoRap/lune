module Lune
  module Capabilities
    class ContextMenu < Lune::Capability
      include Capability::Bindable
      include Capability::WebviewInject

      DESCRIPTOR = Descriptor.new(id: :context_menu, label: "ContextMenu", deps: [:events])

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @handle : Void* = Pointer(Void).null

      def setup(ctx : SetupCtx) : Nil
        @handle = ctx.handle
      end

      def install(ctx : BindCtx) : Nil
        h = @handle
        ctx.register(Definition.new(
          name: "#{name}.show",
          args: ["Float64", "Float64", "String"],
          arg_names: ["x", "y", "itemsJson"],
          return_type: "Nil",
          callback: ->(args : Array(JSON::Any)) {
            Lune::Native::Menu.show_context_menu(h, args[0].as_f.to_f32, args[1].as_f.to_f32, args[2].as_s) do |id|
              ctx.app.events.emit("context_menu", {"id" => id})
            end
            JSON::Any.new(nil)
          },
        ).binding(binding_namespace))
      end

      def init_webview(wv : Webview::Webview, handle : Pointer(Void), app : Lune::App) : Nil
        init_webview(WebviewCtx.new(wv, handle, app, Set(Symbol).new))
      end

      def init_webview(ctx : WebviewCtx) : Nil
        bm = BRIDGE_MARKER
        ctx_show_id = "#{bm}.context_menu.show"
        ctx.wv.init(<<-JS)
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
