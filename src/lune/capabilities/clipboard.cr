module Lune
  module Capabilities
    class Clipboard < Lune::Capability
      include Capability::Bindable

      DESCRIPTOR = Descriptor.new(id: :clipboard, label: "Clipboard")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      DEFAULT_READ = -> {
        {% if flag?(:win32) %}
          # Win32 CF_UNICODETEXT via Lune::Native::Clipboard — instant + safe
          # to call from the webview Isolated thread. The previous PowerShell
          # shellout was ~200-500ms and tripped concurrency-disabled errors.
          Lune::Native::Clipboard.read
        {% else %}
          output = IO::Memory.new
          begin
            status = {% if flag?(:darwin) %}
                       Process.run("pbpaste", output: output)
                     {% else %}
                       Process.run("xclip", ["-o", "-selection", "clipboard"], output: output)
                     {% end %}
            Lune.logger.warn { "Clipboard: read command failed (exit #{status.exit_code})" } unless status.success?
          rescue ex : File::Error | IO::Error
            Lune.logger.warn { "Clipboard: read command unavailable — #{ex.message}" }
          end
          output.to_s.chomp
        {% end %}
      }

      DEFAULT_WRITE = ->(text : String) {
        {% if flag?(:win32) %}
          Lune::Native::Clipboard.write(text)
        {% else %}
          begin
            status = {% if flag?(:darwin) %}
                       Process.run("pbcopy", input: IO::Memory.new(text))
                     {% else %}
                       Process.run("xclip", ["-i", "-selection", "clipboard"], input: IO::Memory.new(text))
                     {% end %}
            Lune.logger.warn { "Clipboard: write command failed (exit #{status.exit_code})" } unless status.success?
          rescue ex : File::Error | IO::Error
            Lune.logger.warn { "Clipboard: write command unavailable — #{ex.message}" }
          end
          nil
        {% end %}
      }

      DEFAULT_READ_HTML   = -> { Lune::Native::Clipboard.read_html }
      DEFAULT_WRITE_HTML  = ->(html : String) { Lune::Native::Clipboard.write_html(html); nil }
      DEFAULT_READ_IMAGE  = -> { Lune::Native::Clipboard.read_image }
      DEFAULT_WRITE_IMAGE = ->(data_url : String) { Lune::Native::Clipboard.write_image(data_url); nil }

      def initialize(
        @on_read : -> String = DEFAULT_READ,
        @on_write : String -> Nil = DEFAULT_WRITE,
        @on_read_html : -> String = DEFAULT_READ_HTML,
        @on_write_html : String -> Nil = DEFAULT_WRITE_HTML,
        @on_read_image : -> String = DEFAULT_READ_IMAGE,
        @on_write_image : String -> Nil = DEFAULT_WRITE_IMAGE,
      )
      end

      def install(ctx : BindCtx) : Nil
        [
          {"read", @on_read},
          {"read_html", @on_read_html},
          {"read_image", @on_read_image},
        ].each do |(method, reader)|
          ctx.register(Definition.new(
            name: "#{name}.#{method}",
            args: [] of String,
            return_type: "String",
            callback: ->(_args : Array(JSON::Any)) { JSON::Any.new(reader.call) },
          ).binding(binding_namespace))
        end

        [
          {"write", "text", @on_write},
          {"write_html", "html", @on_write_html},
          {"write_image", "dataUrl", @on_write_image},
        ].each do |(method, arg_name, writer)|
          ctx.register(Definition.new(
            name: "#{name}.#{method}",
            args: ["String"],
            return_type: "Nil",
            arg_names: [arg_name],
            callback: ->(args : Array(JSON::Any)) { writer.call(args[0].as_s); JSON::Any.new(nil) },
          ).binding(binding_namespace))
        end
      end
    end
  end
end
