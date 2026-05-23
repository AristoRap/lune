module Lune
  module Plugins
    # Maps cmd/ctrl + A/C/V/X/Z/Y to native edit commands inside the webview.
    # Default-on; disable via `lune.yml` plugins.disabled if the app
    # wants to handle these keys itself.
    class EditShortcuts < Lune::Plugin
      DESCRIPTOR = Descriptor.new(id: :edit_shortcuts, label: "EditShortcuts")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      def init_js : String?
        <<-JS
        (function(){
          function isEditable(el) {
            if (!el) return false;
            var tag = el.tagName;
            if (tag === 'INPUT' || tag === 'TEXTAREA') return true;
            return !!el.isContentEditable;
          }
          document.addEventListener('keydown', function(e) {
            if (!e.metaKey && !e.ctrlKey) return;
            // Editable targets get native handling. WebView2/Chromium block
            // `document.execCommand('paste')` for security, so intercepting
            // would suppress the working native handler with a silent
            // failure (broken Ctrl+V on Win32). INPUT/TEXTAREA also handle
            // copy/cut/undo natively, so deferring across the board is
            // safe — the intercept only matters for non-editable contexts
            // (e.g. Cmd+C copying a text selection on a <div>).
            if (isEditable(e.target)) return;
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
