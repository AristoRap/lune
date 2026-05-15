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
          @on_write : String -> Nil = DEFAULT_WRITE
        )
        end

        def install(app : Lune::App)
          read(app)
          write(app)
        end

        private def read(app : Lune::App)
          app.bind(
            namespace: "runtime",
            method: "__lune.clipboardRead",
            args: [] of String,
            return_type: "String",
            async: true,
            runtime: true
          ) do |_args|
            JSON::Any.new(@on_read.call)
          end
        end

        private def write(app : Lune::App)
          app.bind(
            namespace: "runtime",
            method: "__lune.clipboardWrite",
            args: ["String"],
            return_type: "Nil",
            async: true,
            runtime: true
          ) do |args|
            @on_write.call(args[0].as_s)
            JSON::Any.new(nil)
          end
        end
      end
    end
  end
end
