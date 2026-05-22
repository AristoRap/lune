module Lune
  module Capabilities
    class Clipboard < Lune::Capability
      include Lune::Bindable

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

      DEFAULT_READ_HTML  = -> { Lune::Native::Clipboard.read_html }
      DEFAULT_WRITE_HTML = ->(html : String) { Lune::Native::Clipboard.write_html(html); nil }

      # Image clipboard needs PNG ↔ CF_DIB conversion on Win32 (Crystal stdlib has
      # no PNG decoder). Until that's wired up, surface a typed Lune::Error so JS
      # callers see LuneError("UNAVAILABLE_ON_PLATFORM") and can `.catch` it the
      # same way they handle platform-gated capabilities.
      DEFAULT_READ_IMAGE = -> {
        {% if flag?(:win32) %}
          raise Lune::Error.new("UNAVAILABLE_ON_PLATFORM", "Clipboard.readImage is not available on win32 (PNG ↔ CF_DIB conversion not yet implemented)")
        {% else %}
          Lune::Native::Clipboard.read_image
        {% end %}
      }
      DEFAULT_WRITE_IMAGE = ->(data_url : String) {
        {% if flag?(:win32) %}
          raise Lune::Error.new("UNAVAILABLE_ON_PLATFORM", "Clipboard.writeImage is not available on win32 (PNG ↔ CF_DIB conversion not yet implemented)")
        {% else %}
          Lune::Native::Clipboard.write_image(data_url); nil
        {% end %}
      }

      def initialize(
        @on_read : -> String = DEFAULT_READ,
        @on_write : String -> Nil = DEFAULT_WRITE,
        @on_read_html : -> String = DEFAULT_READ_HTML,
        @on_write_html : String -> Nil = DEFAULT_WRITE_HTML,
        @on_read_image : -> String = DEFAULT_READ_IMAGE,
        @on_write_image : String -> Nil = DEFAULT_WRITE_IMAGE,
      )
      end

      @[Lune::Bind]
      def read : String
        @on_read.call
      end

      @[Lune::Bind]
      def read_html : String
        @on_read_html.call
      end

      @[Lune::Bind]
      def read_image : String
        @on_read_image.call
      end

      @[Lune::Bind]
      def write(text : String) : Nil
        @on_write.call(text)
      end

      @[Lune::Bind]
      def write_html(html : String) : Nil
        @on_write_html.call(html)
      end

      @[Lune::Bind]
      @[Lune::BindOverride(arg_names: ["dataUrl"])]
      def write_image(data_url : String) : Nil
        @on_write_image.call(data_url)
      end
    end
  end
end
