module Lune
  module Plugins
    class Events < Lune::Plugin
      include Lune::Bindable

      DESCRIPTOR = Descriptor.new(id: :events, label: "Events", core: true)

      def descriptor : Descriptor
        DESCRIPTOR
      end

      def binding_namespace : String
        "Events"
      end

      # JS-→-Crystal event dispatch. Generated stub on `runtime.Events.emit`
      # routes directly here; no hand-binding, no helper layer.
      @[Lune::Bind]
      @[Lune::BindOverride(arg_names: ["name", "data"], ts_args: ["string", "unknown"] of String?, ts_return_type: "Promise<void>")]
      def emit(name : String, data : JSON::Any) : Nil
        @app.events.dispatch(name, data)
      end

      def init_js : String?
        bm = BRIDGE_MARKER
        <<-JS
        (function(){
          window.#{bm} = window.#{bm} || {};
          var _ll = {};
          window.#{bm}.crystalEmit = function(name, data) {
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
          window.#{bm}.on = function(name, cb, max) {
            (_ll[name] = _ll[name] || []).push({ cb: cb, n: 0, max: max === undefined ? -1 : max });
          };
          window.#{bm}.off = function(name, cb) {
            if (!cb) { delete _ll[name]; return; }
            if (_ll[name]) _ll[name] = _ll[name].filter(function(e) { return e.cb !== cb; });
          };
        })();
        JS
      end

      def js_helpers : String
        bm = BRIDGE_MARKER
        <<-JS
          on(name, cb)     { window.#{bm}.on(name, cb, -1); },
          once(name, cb)   { window.#{bm}.on(name, cb,  1); },
          off(name, cb)    { window.#{bm}.off(name, cb); },
        JS
      end

      def dts_helpers : String
        <<-DTS
          on(name: string, cb: (data: unknown) => void): void;
          once(name: string, cb: (data: unknown) => void): void;
          off(name: string, cb?: (data: unknown) => void): void;
        DTS
      end
    end
  end
end
