module Lune
  module Capabilities
    class DisableContextMenu < Lune::Capability
      def initialize(@enabled : Bool = false)
      end

      def name : String
        "disable_context_menu"
      end

      def core? : Bool
        true
      end

      def init_webview(wv : Webview::Webview, handle : Pointer(Void), app : Lune::App) : Nil
        return unless @enabled
        wv.init("document.addEventListener('contextmenu',function(e){e.preventDefault();});")
      end
    end
  end
end
