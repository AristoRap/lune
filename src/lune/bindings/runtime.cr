module Lune
  module Bindings
    module Runtime
      DEFAULT_OPEN_URL = ->(url : String) {
        {% if flag?(:darwin) %}
          Process.run("open", [url])
        {% else %}
          Process.run("xdg-open", [url])
        {% end %}
        nil
      }

      DEFAULT_READ_CLIPBOARD = -> {
        output = IO::Memory.new
        {% if flag?(:darwin) %}
          Process.run("pbpaste", output: output)
        {% elsif flag?(:win32) %}
          Process.run("powershell.exe", ["-NoProfile", "-Command", "Get-Clipboard"], output: output)
        {% else %}
          Process.run("xclip", ["-o", "-selection", "clipboard"], output: output)
        {% end %}
        output.to_s.chomp
      }

      DEFAULT_WRITE_CLIPBOARD = ->(text : String) {
        {% if flag?(:darwin) %}
          input = IO::Memory.new(text)
          Process.run("pbcopy", input: input)
        {% elsif flag?(:win32) %}
          input = IO::Memory.new(text)
          Process.run("clip.exe", input: input)
        {% else %}
          input = IO::Memory.new(text)
          Process.run("xclip", ["-i", "-selection", "clipboard"], input: input)
        {% end %}
        nil
      }

      def self.filter(bindings : Array(BindingDef), capabilities : Array(String)?) : Array(BindingDef)
        return bindings if capabilities.nil?
        bindings.select { |b| capabilities.includes?(b.name.lchop("__lune.")) }
      end

      def self.build(
        on_quit : -> Nil,
        on_open_url : String -> Nil = DEFAULT_OPEN_URL,
        on_read_clipboard : -> String = DEFAULT_READ_CLIPBOARD,
        on_write_clipboard : String -> Nil = DEFAULT_WRITE_CLIPBOARD,
        debug : Bool = false,
      ) : Array(BindingDef)
        [
          BindingDef.new(
            "__lune.quit",
            "runtime",
            [] of String,
            "Nil",
            ->(args : Array(JSON::Any)) {
              on_quit.call
              JSON::Any.new(nil)
            },
            internal: true,
            async: false
          ),

          BindingDef.new(
            "__lune.openURL",
            "runtime",
            ["String"],
            "Nil",
            ->(args : Array(JSON::Any)) {
              on_open_url.call(args[0].as_s)
              JSON::Any.new(nil)
            },
            internal: true,
            async: true
          ),

          BindingDef.new(
            "__lune.environment",
            "runtime",
            [] of String,
            "JSON",
            ->(_args : Array(JSON::Any)) {
              os =
                {% if flag?(:darwin) %}
                  "darwin"
                {% elsif flag?(:linux) %}
                  "linux"
                {% else %}
                  "windows"
                {% end %}

              arch =
                {% if flag?(:aarch64) %}
                  "arm64"
                {% else %}
                  "x86_64"
                {% end %}

              JSON.parse({os: os, arch: arch, debug: debug}.to_json)
            },
            internal: true,
            async: false
          ),

          BindingDef.new(
            "__lune.homeDir",
            "runtime",
            [] of String,
            "String",
            ->(_args : Array(JSON::Any)) { JSON::Any.new(Path.home.to_s) },
            internal: true,
            async: false
          ),

          BindingDef.new(
            "__lune.tempDir",
            "runtime",
            [] of String,
            "String",
            ->(_args : Array(JSON::Any)) { JSON::Any.new(Dir.tempdir) },
            internal: true,
            async: false
          ),

          BindingDef.new(
            "__lune.downloadsDir",
            "runtime",
            [] of String,
            "String",
            ->(_args : Array(JSON::Any)) {
              JSON::Any.new(Path.home.join("Downloads").to_s)
            },
            internal: true,
            async: false
          ),

          BindingDef.new(
            "__lune.appDataDir",
            "runtime",
            [] of String,
            "String",
            ->(_args : Array(JSON::Any)) {
              path =
                {% if flag?(:darwin) %}
                  Path.home.join("Library", "Application Support").to_s
                {% elsif flag?(:win32) %}
                  ENV["APPDATA"]? || Path.home.to_s
                {% else %}
                  ENV["XDG_DATA_HOME"]? || Path.home.join(".local", "share").to_s
                {% end %}
              JSON::Any.new(path)
            },
            internal: true,
            async: false
          ),

          BindingDef.new(
            "__lune.clipboardRead",
            "runtime",
            [] of String,
            "String",
            ->(_args : Array(JSON::Any)) { JSON::Any.new(on_read_clipboard.call) },
            internal: true,
            async: true
          ),

          BindingDef.new(
            "__lune.clipboardWrite",
            "runtime",
            ["String"],
            "Nil",
            ->(args : Array(JSON::Any)) {
              on_write_clipboard.call(args[0].as_s)
              JSON::Any.new(nil)
            },
            internal: true,
            async: true
          ),
        ]
      end
    end
  end
end
