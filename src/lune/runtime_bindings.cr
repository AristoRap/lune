module Lune
  module RuntimeBindings
    DEFAULT_OPEN_URL = ->(url : String) {
      {% if flag?(:darwin) %}
        Process.run("open", [url])
      {% else %}
        Process.run("xdg-open", [url])
      {% end %}
      nil
    }

    def self.register(
      bridge : Bridge,
      on_quit : -> Nil,
      on_open_url : String -> Nil = DEFAULT_OPEN_URL,
      debug : Bool = false
    )
      bridge.bind_internal("__lune.quit") do |_args|
        on_quit.call
        JSON::Any.new(nil)
      end

      bridge.bind_internal("__lune.openURL") do |args|
        on_open_url.call(args[0].as_s)
        JSON::Any.new(nil)
      end

      bridge.bind_internal("__lune.environment") do |_args|
        os = {% if flag?(:darwin) %}"darwin"{% elsif flag?(:linux) %}"linux"{% else %}"windows"{% end %}
        arch = {% if flag?(:aarch64) %}"arm64"{% else %}"x86_64"{% end %}
        JSON.parse({os: os, arch: arch, debug: debug}.to_json)
      end
    end
  end
end
