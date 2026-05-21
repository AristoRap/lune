module Lune
  module Capabilities
    # Blocks the browser's default right-click context menu when
    # `opts.disable_context_menu = true`. Independent of the `ContextMenu`
    # capability (which shows custom native menus); the two compose — block
    # the default, then let `ContextMenu` show your own.
    class ContextMenuBlocker < Lune::Capability
      include Capability::WebviewInject

      DESCRIPTOR = Descriptor.new(id: :context_menu_blocker, label: "ContextMenuBlocker")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @enabled = false

      def setup(ctx : SetupCtx) : Nil
        @enabled = ctx.options.disable_context_menu
      end

      def init_webview(ctx : WebviewCtx) : Nil
        return unless @enabled
        ctx.wv.init("document.addEventListener('contextmenu',function(e){e.preventDefault();});")
      end
    end
  end
end
