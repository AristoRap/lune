require "json"

module Lune
  module Runtime
    module Bindings
      class Clipboard
        include Lune::Installable

        DEFAULT_READ = -> {
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

        DEFAULT_WRITE = ->(text : String) {
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

        def initialize(
          @on_read : -> String = DEFAULT_READ,
          @on_write : String -> Nil = DEFAULT_WRITE,
        )
        end

        def install(app : Lune::App)
          read(app)
          write(app)
        end

        private def read(app : Lune::App)
          app.register(Lune::RuntimeBinding.new(
            namespace: "runtime",
            method: "__lune.clipboardRead",
            args: [] of String,
            return_type: "String",
            callback: ->(_args : Array(JSON::Any)) { JSON::Any.new(@on_read.call) },
            async: false,
          ))
        end

        private def write(app : Lune::App)
          app.register(Lune::RuntimeBinding.new(
            namespace: "runtime",
            method: "__lune.clipboardWrite",
            args: ["String"],
            return_type: "Nil",
            callback: ->(args : Array(JSON::Any)) {
              @on_write.call(args[0].as_s)
              JSON::Any.new(nil)
            },
            async: false,
            arg_names: ["text"],
          ))
        end
      end
    end
  end
end
