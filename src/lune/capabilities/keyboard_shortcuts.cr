module Lune
  module Capabilities
    class KeyboardShortcuts < Lune::Capability
      def name : String
        "keyboard_shortcuts"
      end

      def core? : Bool
        true
      end

      def init_webview(wv : Webview::Webview, handle : Pointer(Void), app : Lune::App) : Nil
        wv.init(<<-JS)
        (function(){
          document.addEventListener('keydown', function(e) {
            if (!e.metaKey && !e.ctrlKey) return;
            var cmd;
            switch (e.key) {
              case 'a': cmd = 'selectAll'; break;
              case 'c': cmd = 'copy'; break;
              case 'v': cmd = 'paste'; break;
              case 'x': cmd = 'cut'; break;
              case 'z': cmd = e.shiftKey ? 'redo' : 'undo'; break;
              case 'y': cmd = 'redo'; break;
            }
            if (cmd) { e.preventDefault(); document.execCommand(cmd); }
          });
        })();
        JS
      end
    end
  end
end
