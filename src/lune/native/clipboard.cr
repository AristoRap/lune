require "base64"

module Lune
  module Native
    {% if flag?(:lune_native_test_mock) %}
      module ClipboardMock
        @@html : String = ""
        @@image : String = ""

        class_getter html, image

        def self.reset
          @@html = ""
          @@image = ""
        end

        def self.stub_html(html : String);   @@html = html;   end
        def self.stub_image(image : String); @@image = image; end

        def self.record_read_html : String;                    @@html;  end
        def self.record_write_html(html : String);             @@html = html;      end
        def self.record_read_image : String;                   @@image; end
        def self.record_write_image(data_url : String);        @@image = data_url; end
      end
    {% elsif flag?(:darwin) %}
      {% system("cd '#{__DIR__}/../../../ext/native/macos' && clang -c clipboard.m -o clipboard.o -fobjc-arc 2>/dev/null") %}

      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../ext/native/macos/clipboard.o")]
      lib LibNativeClipboard
        fun clipboard_read_html(out : LibC::Char*, out_size : LibC::Int) : LibC::Int
        fun clipboard_write_html(html : LibC::Char*) : Void
        fun clipboard_read_image(out : LibC::Char*, out_size : LibC::Int) : LibC::Int
        fun clipboard_write_image(data_url : LibC::Char*) : Void
      end
    {% end %}

    module Clipboard
      HTML_BUF_SIZE  =  1 * 1024 * 1024  # 1 MB — generous for any HTML payload
      IMAGE_BUF_SIZE = 10 * 1024 * 1024  # 10 MB — covers base64 of most clipboard images

      def self.read_html : String
        {% if flag?(:lune_native_test_mock) %}
          ClipboardMock.record_read_html
        {% elsif flag?(:darwin) %}
          buf = Bytes.new(HTML_BUF_SIZE)
          return "" if LibNativeClipboard.clipboard_read_html(buf.to_unsafe.as(LibC::Char*), HTML_BUF_SIZE) == 0
          String.new(buf.to_unsafe)
        {% elsif flag?(:linux) %}
          output = IO::Memory.new
          Process.run("xclip", ["-o", "-selection", "clipboard", "-t", "text/html"], output: output)
          output.to_s
        {% elsif flag?(:win32) %}
          raise NotImplementedError.new("Lune::Native::Clipboard.read_html is not implemented on Windows yet (v0.10.0 backlog)")
        {% else %}
          ""
        {% end %}
      end

      def self.write_html(html : String) : Nil
        {% if flag?(:lune_native_test_mock) %}
          ClipboardMock.record_write_html(html)
        {% elsif flag?(:darwin) %}
          LibNativeClipboard.clipboard_write_html(html)
        {% elsif flag?(:linux) %}
          input = IO::Memory.new(html)
          Process.run("xclip", ["-i", "-selection", "clipboard", "-t", "text/html"], input: input)
        {% elsif flag?(:win32) %}
          raise NotImplementedError.new("Lune::Native::Clipboard.write_html is not implemented on Windows yet (v0.10.0 backlog)")
        {% end %}
      end

      def self.read_image : String
        {% if flag?(:lune_native_test_mock) %}
          ClipboardMock.record_read_image
        {% elsif flag?(:darwin) %}
          buf = Bytes.new(IMAGE_BUF_SIZE)
          return "" if LibNativeClipboard.clipboard_read_image(buf.to_unsafe.as(LibC::Char*), IMAGE_BUF_SIZE) == 0
          b64 = String.new(buf.to_unsafe)
          b64.empty? ? "" : "data:image/png;base64,#{b64}"
        {% elsif flag?(:linux) %}
          output = IO::Memory.new
          status = Process.run("xclip", ["-o", "-selection", "clipboard", "-t", "image/png"], output: output)
          return "" unless status.success?
          raw = output.to_slice
          raw.empty? ? "" : "data:image/png;base64,#{Base64.strict_encode(raw)}"
        {% elsif flag?(:win32) %}
          raise NotImplementedError.new("Lune::Native::Clipboard.read_image is not implemented on Windows yet (v0.10.0 backlog)")
        {% else %}
          ""
        {% end %}
      end

      def self.write_image(data_url : String) : Nil
        {% if flag?(:lune_native_test_mock) %}
          ClipboardMock.record_write_image(data_url)
        {% elsif flag?(:darwin) %}
          LibNativeClipboard.clipboard_write_image(data_url)
        {% elsif flag?(:linux) %}
          b64 = data_url.includes?(",") ? data_url.split(",", 2).last : data_url
          raw = Base64.decode(b64)
          input = IO::Memory.new(raw)
          Process.run("xclip", ["-i", "-selection", "clipboard", "-t", "image/png"], input: input)
        {% elsif flag?(:win32) %}
          raise NotImplementedError.new("Lune::Native::Clipboard.write_image is not implemented on Windows yet (v0.10.0 backlog)")
        {% end %}
      end
    end
  end
end
