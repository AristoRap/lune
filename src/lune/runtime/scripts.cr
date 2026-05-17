module Lune
  module Runtime
    module Scripts
      NAVIGATION = <<-JS
        (function(){
          function _lune_nav(){ window.__lune_navigate(location.href); }
          window.addEventListener('popstate', _lune_nav);
          window.addEventListener('hashchange', _lune_nav);
        })();
      JS

      DISABLE_CONTEXT_MENU = "document.addEventListener('contextmenu',function(e){e.preventDefault();});"

      def self.core : String
        "(function(){\n#{keyboard_shortcuts}\n#{event_bus}\n})();"
      end

      def self.drag_zone(css_var : String, css_val : String) : String
        <<-JS
          (function(){
            document.addEventListener('mousedown', function(e) {
              var el = e.target;
              while (el) {
                if (el.style && el.style.getPropertyValue(#{css_var.inspect}).trim() === #{css_val.inspect}) {
                  window.__lune_start_window_drag();
                  return;
                }
                el = el.parentElement;
              }
            }, true);
          })();
        JS
      end

      def self.file_drop(css_prop : String? = nil, css_val : String? = nil) : String
        drop_zone = ""
        if css_prop && css_val
          drop_zone = <<-JS
            var _lune_dz_prop = #{css_prop.inspect};
            var _lune_dz_val  = #{css_val.inspect};
            var _lune_dz_active = null;
            window.__lune_drag_pos = function(x, y) {
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
            window.__lune_drop_check = function(x, y, pathsJson) {
              if (_lune_dz_active) {
                _lune_dz_active.classList.remove('lune-drop-target-active');
                _lune_dz_active = null;
                window.__lune_emit("fileDrop", { x: x, y: y, paths: JSON.parse(pathsJson) });
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

      private def self.keyboard_shortcuts : String
        <<-JS
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
        JS
      end

      private def self.event_bus : String
        <<-JS
          var _ll = {};
          window.__lune_emit = function(name, data) {
            var ls = _ll[name];
            if (!ls) return;
            var keep = [];
            for (var i = 0; i < ls.length; i++) {
              ls[i].cb(data);
              ls[i].n++;
              if (ls[i].max < 0 || ls[i].n < ls[i].max) keep.push(ls[i]);
            }
            _ll[name] = keep;
          };
          window.__lune_on = function(name, cb, max) {
            (_ll[name] = _ll[name] || []).push({ cb: cb, n: 0, max: max === undefined ? -1 : max });
          };
          window.__lune_off = function(name, cb) {
            if (!cb) { delete _ll[name]; return; }
            if (_ll[name]) _ll[name] = _ll[name].filter(function(e) { return e.cb !== cb; });
          };
        JS
      end
    end
  end
end
