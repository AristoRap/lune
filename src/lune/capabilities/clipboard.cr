module Lune
  module Capabilities
    class Clipboard < Lune::Capability
      include Capability::Bindable

      DESCRIPTOR = Descriptor.new(id: :clipboard, label: "Clipboard")

      def descriptor : Descriptor
        DESCRIPTOR
      end

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
          Process.run("pbcopy", input: IO::Memory.new(text))
        {% elsif flag?(:win32) %}
          Process.run("clip.exe", input: IO::Memory.new(text))
        {% else %}
          Process.run("xclip", ["-i", "-selection", "clipboard"], input: IO::Memory.new(text))
        {% end %}
        nil
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

      def install(app : App) : Nil
        install(BindCtx.new(app))
      end

      def install(ctx : BindCtx) : Nil
        on_read = @on_read
        ctx.register(Definition.new(
          name: "#{name}.read",
          args: [] of String,
          return_type: "String",
          callback: ->(_args : Array(JSON::Any)) { JSON::Any.new(on_read.call) },
        ).binding(binding_namespace))

        on_write = @on_write
        ctx.register(Definition.new(
          name: "#{name}.write",
          args: ["String"],
          return_type: "Nil",
          arg_names: ["text"],
          callback: ->(args : Array(JSON::Any)) { on_write.call(args[0].as_s); JSON::Any.new(nil) },
        ).binding(binding_namespace))

        on_read_html = @on_read_html
        ctx.register(Definition.new(
          name: "#{name}.read_html",
          args: [] of String,
          return_type: "String",
          callback: ->(_args : Array(JSON::Any)) { JSON::Any.new(on_read_html.call) },
        ).binding(binding_namespace))

        on_write_html = @on_write_html
        ctx.register(Definition.new(
          name: "#{name}.write_html",
          args: ["String"],
          return_type: "Nil",
          arg_names: ["html"],
          callback: ->(args : Array(JSON::Any)) { on_write_html.call(args[0].as_s); JSON::Any.new(nil) },
        ).binding(binding_namespace))

        on_read_image = @on_read_image
        ctx.register(Definition.new(
          name: "#{name}.read_image",
          args: [] of String,
          return_type: "String",
          callback: ->(_args : Array(JSON::Any)) { JSON::Any.new(on_read_image.call) },
        ).binding(binding_namespace))

        on_write_image = @on_write_image
        ctx.register(Definition.new(
          name: "#{name}.write_image",
          args: ["String"],
          return_type: "Nil",
          arg_names: ["dataUrl"],
          callback: ->(args : Array(JSON::Any)) { on_write_image.call(args[0].as_s); JSON::Any.new(nil) },
        ).binding(binding_namespace))
      end
    end
  end
end
