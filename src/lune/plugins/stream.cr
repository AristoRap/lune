require "http/web_socket"

module Lune
  module Plugins
    # Logs every HTTP request that enters the stream server's handler chain.
    # Sits before the WebSocketHandler so we can tell whether the request was
    # ever parsed (vs. stuck at TCP accept) and whether the Upgrade header was
    # what we expected. Debug-only.
    private class StreamRequestLogHandler
      include HTTP::Handler

      def call(context)
        Lune.logger.debug do
          headers = context.request.headers
          "Stream: HTTP req method=#{context.request.method} path=#{context.request.path} upgrade=#{headers["Upgrade"]?.inspect} connection=#{headers["Connection"]?.inspect}"
        end
        call_next(context)
      end
    end

    class Stream < Lune::Plugin
      include Plugin::WebviewInject

      DESCRIPTOR = Descriptor.new(id: :stream, label: "Stream", core: true)

      def descriptor : Descriptor
        DESCRIPTOR
      end

      def binding_namespace : String
        "Stream"
      end

      def init_webview(wv : Webview::Webview, handle : Pointer(Void), app : Lune::App) : Nil
        init_webview(WebviewCtx.new(wv, handle, app, Set(Symbol).new))
      end

      @port : Int32 = 0

      def init_webview(ctx : WebviewCtx) : Nil
        return if @port != 0
        app = ctx.app
        sockets = [] of HTTP::WebSocket
        mu = Mutex.new

        handlers = [
          StreamRequestLogHandler.new,
          HTTP::WebSocketHandler.new do |ws, _ctx|
            Lune.logger.debug { "Stream: WS client connected" }
            mu.synchronize { sockets << ws }
            ws.on_message do |raw|
              begin
                msg = JSON.parse(raw)
                app.stream.dispatch(msg["n"].as_s, msg["d"])
              rescue ex
                Lune.logger.debug { "Stream: malformed message — #{ex.message}" }
              end
            end
            ws.on_close { Lune.logger.debug { "Stream: WS client disconnected" }; mu.synchronize { sockets.delete(ws) } }
          end,
        ] of HTTP::Handler
        server = HTTP::Server.new(handlers)

        {% if flag?(:win32) %}
          # Windows: IOCP affinity. The listening socket gets bound to whichever
          # context's IOCP first does I/O on it. If bind happens here (webview
          # Isolated) and listen on a separate pool, accept/read completions get
          # routed to the wrong IOCP and per-connection fibers park forever. So
          # bind AND listen from the same spawned fiber on the default context,
          # and signal the bound port back via a Channel.
          port_ready = ::Channel(Int32).new(1)
          ::spawn(name: "lune-stream-listen") do
            addr = server.bind_tcp("127.0.0.1", 0)
            port_ready.send(addr.port)
            Lune.logger.debug { "Stream: server.listen starting on default ctx, port=#{addr.port}" }
            server.listen
            Lune.logger.debug { "Stream: server.listen returned" }
          end
          @port = port_ready.receive
        {% else %}
          # macOS/Linux: the webview isn't Isolated here but `wv.run` is a
          # blocking C call that never yields, so fibers spawned on the default
          # context would starve. Use a dedicated Parallel pool with its own OS
          # threads so the accept loop runs independently. No IOCP affinity to
          # worry about (kqueue/epoll), so binding before the spawn is fine.
          addr = server.bind_tcp("127.0.0.1", 0)
          @port = addr.port
          pool = Fiber::ExecutionContext::Parallel.new("lune-stream", 2)
          pool.spawn(name: "lune-stream-listen") do
            Lune.logger.debug { "Stream: server.listen starting on Parallel pool, port=#{@port}" }
            server.listen
            Lune.logger.debug { "Stream: server.listen returned" }
          end
        {% end %}
        Lune.logger.debug { "Stream: WS server bound on 127.0.0.1:#{@port}" }

        app.stream.sender = ->(n : String, json : String) {
          copies = mu.synchronize { sockets.dup }
          copies.each { |ws| ws.send(%({"n":#{n.to_json},"d":#{json}})) rescue nil }
        }
      end

      # WebSocket client JS; nil until init_webview has bound the port.
      def init_js : String?
        return nil if @port == 0
        port = @port
        bm = BRIDGE_MARKER
        <<-JS
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
          window.#{bm}.stOn   = function(n,cb){ (_h[n]=_h[n]||[]).push(cb); };
          window.#{bm}.stOff  = function(n,cb){ if(!cb){delete _h[n];return;} if(_h[n]) _h[n]=_h[n].filter(function(f){return f!==cb;}); };
          window.#{bm}.stSend = function(n,d){
            var m = JSON.stringify({n:n, d:d===undefined?null:d});
            if(_ws && _ws.readyState===1) _ws.send(m); else _q.push(m);
          };
        })();
        JS
      end

      def js_helpers : String
        bm = BRIDGE_MARKER
        <<-JS
          on(name, cb)     { window.#{bm}.stOn(name, cb); },
          once(name, cb)   { var w=function(d){ cb(d); window.#{bm}.stOff(name,w); }; window.#{bm}.stOn(name,w); },
          off(name, cb)    { window.#{bm}.stOff(name, cb); },
          send(name, data) { window.#{bm}.stSend(name, data); },
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
