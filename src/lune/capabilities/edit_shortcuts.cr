module Lune
  module Capabilities
    # Maps cmd/ctrl + A/C/V/X/Z/Y to native edit commands inside the webview.
    # Default-on; disable via `lune.yml` capabilities.disabled if the app
    # wants to handle these keys itself.
    class EditShortcuts < Lune::Capability
      DESCRIPTOR = Descriptor.new(id: :edit_shortcuts, label: "EditShortcuts")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      def init_js : String?
        <<-JS
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
