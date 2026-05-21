require "socket"

module Lune
  # Single-instance URL forwarding over a Unix domain socket. Lets the
  # second launch of an app — invoked by the OS with a scheme URL on its
  # command line — hand the URL off to the already-running primary
  # instance and exit, so the user keeps a single window instead of one
  # window per `myapp://…` click.
  #
  # macOS gets the same behaviour for free from the NSApplication delegate
  # (single-instance is the default), so this is only wired in for Linux
  # in v0.11.0. Windows can join later via named pipes — Crystal's stdlib
  # doesn't expose them today and TCP loopback would be a worse default.
  module DeepLinkIPC
    # Derive a stable socket path from the app's title. Prefers
    # $XDG_RUNTIME_DIR (cleaned up automatically at logout) and falls
    # back to /tmp.
    def self.socket_path(app_name : String) : String
      slug = app_name.downcase.gsub(/[^a-z0-9]+/, "-").lstrip('-').rstrip('-')
      slug = "lune" if slug.empty?
      base = ENV["XDG_RUNTIME_DIR"]? || Dir.tempdir
      File.join(base, "lune-#{slug}.sock")
    end

    # Try to forward `url` to a primary instance listening on the
    # socket. Returns true on success — caller is expected to exit.
    # Returns false if no primary is reachable (stale socket, no
    # listener, permission error, …) — caller should become the primary.
    def self.forward(url : String, app_name : String) : Bool
      path = socket_path(app_name)
      return false unless File.exists?(path)
      sock = UNIXSocket.new(path)
      sock.puts(url)
      sock.close
      true
    rescue Socket::ConnectError | File::Error | IO::Error
      false
    end

    # Bind the socket and run the accept loop in a background fiber.
    # Each successful connection reads one line (the forwarded URL) and
    # invokes the handler. The socket file is cleaned up at process exit.
    def self.listen(app_name : String, &handler : String -> Nil) : UNIXServer?
      path = socket_path(app_name)
      # A leftover socket file from a crashed process would otherwise
      # block our bind. The bind below recreates it.
      File.delete?(path)
      server = UNIXServer.new(path)

      at_exit { File.delete?(path) rescue nil }

      cb = handler
      Fiber::ExecutionContext::Isolated.new("lune-deep-link-ipc") do
        loop do
          client = server.accept?
          break unless client
          begin
            url = client.gets
            cb.call(url) if url && url.includes?("://")
          rescue IO::Error
          ensure
            client.close
          end
        end
      end

      server
    rescue Socket::BindError | File::Error | IO::Error
      nil
    end
  end
end
