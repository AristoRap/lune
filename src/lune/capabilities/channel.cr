require "http/web_socket"

module Lune
  module Capabilities
    class Channel < Lune::Capability
      include Capability::WebviewInject

      DESCRIPTOR = Descriptor.new(id: :channel, label: "Channel", core: true)

      def descriptor : Descriptor
        DESCRIPTOR
      end

      def binding_namespace : String
        "Channel"
      end

      def init_webview(wv : Webview::Webview, handle : Pointer(Void), app : Lune::App) : Nil
        init_webview(WebviewCtx.new(wv, handle, app, Set(Symbol).new))
      end

      def init_webview(ctx : WebviewCtx) : Nil
        wv = ctx.wv
        app = ctx.app
        sockets = [] of HTTP::WebSocket
        mu = Mutex.new

        server = HTTP::Server.new([
          HTTP::WebSocketHandler.new do |ws, _ctx|
            mu.synchronize { sockets << ws }
            ws.on_message do |raw|
              begin
                msg = JSON.parse(raw)
                app.dispatch_channel_message(msg["n"].as_s, msg["d"])
              rescue
              end
            end
            ws.on_close { mu.synchronize { sockets.delete(ws) } }
          end,
        ])

        addr = server.bind_tcp("127.0.0.1", 0)
        port = addr.port

        pool = Fiber::ExecutionContext::Parallel.new("lune-channel-pool", 2)
        ready = ::Channel(Nil).new
        Fiber::ExecutionContext::Isolated.new("lune-channel", spawn_context: pool) do
          ready.send(nil)
          server.listen
        end
        ready.receive

        app.channel_sender = ->(n : String, json : String) {
          copies = mu.synchronize { sockets.dup }
          copies.each { |ws| ws.send(%({"n":#{n.to_json},"d":#{json}})) rescue nil }
        }

        bm = BRIDGE_MARKER
        wv.init(<<-JS)
        (function(){
          var _h = {};
          var _q = [];
          var _ws;
          function connect() {
            _ws = new WebSocket("ws://127.0.0.1:#{port}");
            _ws.onopen  = function() { _q.splice(0).forEach(function(m){ _ws.send(m); }); };
            _ws.onmessage = function(e) {
              var m; try { m = JSON.parse(e.data); } catch(_){ return; }
              (_h[m.n] || []).forEach(function(cb){ cb(m.d); });
            };
            _ws.onclose = function() { setTimeout(connect, 1000); };
            _ws.onerror = function() { _ws.close(); };
          }
          connect();
          window.#{bm} = window.#{bm} || {};
          window.#{bm}.chOn   = function(n,cb){ (_h[n]=_h[n]||[]).push(cb); };
          window.#{bm}.chOff  = function(n,cb){ if(!cb){delete _h[n];return;} if(_h[n]) _h[n]=_h[n].filter(function(f){return f!==cb;}); };
          window.#{bm}.chSend = function(n,d){
            var m = JSON.stringify({n:n, d:d===undefined?null:d});
            if(_ws && _ws.readyState===1) _ws.send(m); else _q.push(m);
          };
        })();
        JS
      end

      def js_helpers : String
        bm = BRIDGE_MARKER
        <<-JS
          on(name, cb)     { window.#{bm}.chOn(name, cb); },
          once(name, cb)   { var w=function(d){ cb(d); window.#{bm}.chOff(name,w); }; window.#{bm}.chOn(name,w); },
          off(name, cb)    { window.#{bm}.chOff(name, cb); },
          send(name, data) { window.#{bm}.chSend(name, data); },
        JS
      end

      def dts_helpers : String
        <<-DTS
          on(name: string, cb: (data: unknown) => void): void;
          once(name: string, cb: (data: unknown) => void): void;
          off(name: string, cb?: (data: unknown) => void): void;
          send(name: string, data?: unknown): void;
        DTS
      end
    end
  end
end
