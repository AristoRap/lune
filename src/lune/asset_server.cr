require "http/server"

module Lune
  # Serves embedded assets over HTTP on a random local port.
  # Started in a fiber before the webview run loop so the webview can
  # navigate to http://127.0.0.1:<port> instead of using a data: URI.
  # This gives the frontend a real origin — relative imports, fetch, and
  # WebSocket HMR all work correctly.
  class AssetServer
    @server : HTTP::Server
    getter port : Int32

    def initialize
      @server = build_server
      @port = 0
      {% unless flag?(:win32) %}
        # POSIX: bind here (port 0 → OS assigns a free port and keeps the
        # socket open, no TOCTOU race vs acquire-release-rebind). Win32 has
        # to defer bind to #start — see the Win32 branch there.
        addr = @server.bind_tcp("127.0.0.1", 0)
        @port = addr.port
      {% end %}
    end

    def start
      server = @server

      {% if flag?(:win32) %}
        # Windows: IOCP affinity. The listening socket gets bound to whichever
        # context's IOCP first does I/O on it. If we bind here (on the runner's
        # webview Isolated context) and listen on a separate pool, accept
        # completions are routed to the wrong IOCP and per-connection fibers
        # park forever (the asset HTTP server appears to listen but never
        # responds — that's the exact symptom we hit). So bind AND listen
        # from the same spawned fiber on the default context, signalling
        # the bound port back via a Channel. Same pattern as Stream's WS
        # server in capabilities/stream.cr.
        port_ready = Channel(Int32).new(1)
        ::spawn(name: "lune-assets-listen") do
          addr = server.bind_tcp("127.0.0.1", 0)
          port_ready.send(addr.port)
          Lune.logger.debug { "AssetServer: listen starting on default ctx, port=#{addr.port}" }
          server.listen
          Lune.logger.debug { "AssetServer: listen returned" }
        end
        @port = port_ready.receive
      {% else %}
        # POSIX (kqueue/epoll): no IOCP affinity, so binding in #initialize
        # is fine. HTTP::Server spawns a fiber per connection — those fibers
        # need real OS threads (not the default context, whose thread is
        # blocked in wv.run). Parallel pool + Isolated accept loop gives
        # them an independent thread.
        ready = Channel(Nil).new
        pool = Fiber::ExecutionContext::Parallel.new("lune-assets-pool", 2)
        Fiber::ExecutionContext::Isolated.new("lune-assets", spawn_context: pool) do
          ready.send(nil)
          server.listen
        end
        ready.receive
      {% end %}
    end

    # Call after wv.run returns to release the port and stop the fiber.
    def stop
      @server.close
    end

    def url : String
      "http://127.0.0.1:#{@port}"
    end

    private def build_server : HTTP::Server
      HTTP::Server.new do |ctx|
        path = ctx.request.path
        path = "/index.html" if path == "/"

        if content = Assets.get(path)
          ctx.response.content_type = Assets.mime_for(path)
          ctx.response.content_length = content.bytesize
          ctx.response.write(content)
        else
          ctx.response.status = HTTP::Status::NOT_FOUND
          ctx.response.content_type = "text/plain"
          ctx.response.print("404 not found: #{path}")
        end
      end
    end
  end
end
