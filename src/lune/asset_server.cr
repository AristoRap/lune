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

      # Bind to port 0 — the OS assigns a free port and keeps the socket open.
      # This eliminates the TOCTOU race of the old acquire-release-rebind pattern
      # where another process could steal the port between close and bind.
      addr = @server.bind_tcp("127.0.0.1", 0)
      @port = addr.port
    end

    def start
      server = @server
      ready = Channel(Nil).new

      # HTTP::Server spawns a fiber per connection. Those fibers must land on
      # real OS threads — not the default concurrent context whose thread is
      # blocked in the native event loop. Parallel gives them a small thread
      # pool; Isolated runs the accept loop and forwards spawns there.
      pool = Fiber::ExecutionContext::Parallel.new("lune-assets-pool", 2)
      Fiber::ExecutionContext::Isolated.new("lune-assets", spawn_context: pool) do
        ready.send(nil)
        server.listen
      end

      ready.receive
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
