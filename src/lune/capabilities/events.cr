module Lune
  module Capabilities
    class Events < Lune::Capability
      include Capability::WebviewInject

      DESCRIPTOR = Descriptor.new(id: :events, label: "Events", core: true)

      def descriptor : Descriptor
        DESCRIPTOR
      end

      def binding_namespace : String
        "Events"
      end

      def init_webview(wv : Webview::Webview, handle : Pointer(Void), app : Lune::App) : Nil
        init_webview(WebviewCtx.new(wv, handle, app, Set(Symbol).new))
      end

      def init_webview(ctx : WebviewCtx) : Nil
        bm = BRIDGE_MARKER
        wv = ctx.wv
        app = ctx.app

        js_emit_key = "#{BRIDGE_MARKER}.jsEmit"
        wv.bind(js_emit_key, Webview::JSProc.new { |args|
          event = args[0]?.try(&.as_s) || ""
          data = args[1]? || JSON::Any.new(nil)
          app.events.dispatch(event, data)
          JSON::Any.new(nil)
        })

        wv.init(<<-JS)
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
        js_emit_key = "#{BRIDGE_MARKER}.jsEmit"
        <<-JS
          on(name, cb)     { window.#{bm}.on(name, cb, -1); },
          once(name, cb)   { window.#{bm}.on(name, cb,  1); },
          off(name, cb)    { window.#{bm}.off(name, cb); },
          emit(name, data) { return window[#{js_emit_key.inspect}](name, data); },
        JS
      end

      def dts_helpers : String
        <<-DTS
          on(name: string, cb: (data: unknown) => void): void;
          once(name: string, cb: (data: unknown) => void): void;
          off(name: string, cb?: (data: unknown) => void): void;
          emit(name: string, data?: unknown): Promise<void>;
        DTS
      end
    end
  end
end
