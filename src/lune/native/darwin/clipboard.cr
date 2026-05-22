{% if flag?(:darwin) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/macos' && clang -c clipboard.m -o clipboard.o -fobjc-arc 2>/dev/null") %}

  module Lune
    module Native
      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/macos/clipboard.o")]
      lib LibNativeClipboard
        fun clipboard_read_html(out : LibC::Char*, out_size : LibC::Int) : LibC::Int
        fun clipboard_write_html(html : LibC::Char*) : Void
        fun clipboard_read_image(out : LibC::Char*, out_size : LibC::Int) : LibC::Int
        fun clipboard_write_image(data_url : LibC::Char*) : Void
      end

      module Clipboard
        def self.read : String
          raise NotImplementedError.new("Lune::Native::Clipboard.read — use the capability's DEFAULT_READ on non-Windows platforms")
        end

        def self.write(text : String) : Nil
          raise NotImplementedError.new("Lune::Native::Clipboard.write — use the capability's DEFAULT_WRITE on non-Windows platforms")
        end

        def self.read_html : String
          buf = Bytes.new(HTML_BUF_SIZE)
          return "" if LibNativeClipboard.clipboard_read_html(buf.to_unsafe.as(LibC::Char*), HTML_BUF_SIZE) == 0
          String.new(buf.to_unsafe)
        end

        def self.write_html(html : String) : Nil
          LibNativeClipboard.clipboard_write_html(html)
        end

        def self.read_image : String
          buf = Bytes.new(IMAGE_BUF_SIZE)
          return "" if LibNativeClipboard.clipboard_read_image(buf.to_unsafe.as(LibC::Char*), IMAGE_BUF_SIZE) == 0
          b64 = String.new(buf.to_unsafe)
          b64.empty? ? "" : "data:image/png;base64,#{b64}"
        end

        def self.write_image(data_url : String) : Nil
          LibNativeClipboard.clipboard_write_image(data_url)
        end
      end
    end
  end
{% end %}
