require "base64"

module Lune
  module Native
    {% if flag?(:lune_native_test_mock) %}
      module ClipboardMock
        @@text : String = ""
        @@html : String = ""
        @@image : String = ""

        class_getter text, html, image

        def self.reset
          @@text = ""
          @@html = ""
          @@image = ""
        end

        def self.stub_text(text : String);   @@text = text;   end
        def self.stub_html(html : String);   @@html = html;   end
        def self.stub_image(image : String); @@image = image; end

        def self.record_read : String;                         @@text;  end
        def self.record_write(text : String);                  @@text = text;      end
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
    {% elsif flag?(:win32) %}
      @[Link("user32")]
      lib LibUser32Clip
        CF_UNICODETEXT = 13_u32
        fun open_clipboard = OpenClipboard(hwnd : Void*) : LibC::Int
        fun close_clipboard = CloseClipboard : LibC::Int
        fun empty_clipboard = EmptyClipboard : LibC::Int
        fun get_clipboard_data = GetClipboardData(format : UInt32) : Void*
        fun set_clipboard_data = SetClipboardData(format : UInt32, mem : Void*) : Void*
        fun register_clipboard_format_w = RegisterClipboardFormatW(name : UInt16*) : UInt32
      end

      @[Link("kernel32")]
      lib LibKernel32Clip
        GMEM_MOVEABLE = 0x0002_u32
        fun global_alloc = GlobalAlloc(flags : UInt32, bytes : LibC::SizeT) : Void*
        fun global_lock = GlobalLock(mem : Void*) : Void*
        fun global_unlock = GlobalUnlock(mem : Void*) : LibC::Int
        fun global_size = GlobalSize(mem : Void*) : LibC::SizeT
      end
    {% end %}

    module Clipboard
      HTML_BUF_SIZE  =  1 * 1024 * 1024  # 1 MB — generous for any HTML payload
      IMAGE_BUF_SIZE = 10 * 1024 * 1024  # 10 MB — covers base64 of most clipboard images

      {% if flag?(:win32) %}
        # The CF_HTML clipboard format ("HTML Format") is registered, not
        # built-in, so the format ID is obtained once at runtime.
        @@cf_html : UInt32 = 0_u32

        private def self.cf_html : UInt32
          if @@cf_html == 0_u32
            name = "HTML Format".to_utf16
            buf = Pointer(UInt16).malloc(name.size + 1)
            name.size.times { |i| buf[i] = name[i] }
            buf[name.size] = 0_u16
            @@cf_html = LibUser32Clip.register_clipboard_format_w(buf)
          end
          @@cf_html
        end

        # Wraps an HTML fragment in the CF_HTML envelope. The header lists
        # byte offsets of each section; we patch them in after building the
        # body, since the offset widths are fixed (10 digits) but their
        # values depend on the body length.
        private def self.wrap_cf_html(html : String) : String
          header_template = "Version:0.9\r\n" \
                            "StartHTML:%010d\r\n" \
                            "EndHTML:%010d\r\n" \
                            "StartFragment:%010d\r\n" \
                            "EndFragment:%010d\r\n"
          prefix = "<html><body><!--StartFragment-->"
          suffix = "<!--EndFragment--></body></html>"
          header_size = (header_template % {0, 0, 0, 0}).bytesize
          start_html      = header_size
          start_fragment  = start_html + prefix.bytesize
          end_fragment    = start_fragment + html.bytesize
          end_html        = end_fragment + suffix.bytesize
          header = header_template % {start_html, end_html, start_fragment, end_fragment}
          "#{header}#{prefix}#{html}#{suffix}"
        end

        # Strip the CF_HTML envelope and return just the user-visible fragment.
        private def self.unwrap_cf_html(raw : String) : String
          start_marker = "<!--StartFragment-->"
          end_marker   = "<!--EndFragment-->"
          si = raw.index(start_marker)
          ei = raw.index(end_marker)
          return raw unless si && ei && ei > si
          raw[(si + start_marker.bytesize)...ei]
        end
      {% end %}

      # Plaintext read. On Windows we go straight to Win32 CF_UNICODETEXT — the
      # previous PowerShell shellout took ~200-500ms cold-start and (worse)
      # blew up with "Concurrency is disabled in isolated contexts" because
      # Process.run spawns a wait fiber that can't be scheduled on the webview
      # Isolated thread. Other platforms keep their pbpaste/xclip path in the
      # capability layer where Process.run is safe.
      def self.read : String
        {% if flag?(:lune_native_test_mock) %}
          ClipboardMock.record_read
        {% elsif flag?(:win32) %}
          return "" if LibUser32Clip.open_clipboard(Pointer(Void).null) == 0
          begin
            mem = LibUser32Clip.get_clipboard_data(LibUser32Clip::CF_UNICODETEXT)
            return "" if mem.null?
            ptr = LibKernel32Clip.global_lock(mem)
            return "" if ptr.null?
            begin
              # `String.from_utf16(Pointer)` returns `{String, Pointer}` —
              # second element is the pointer past the null terminator.
              str, _ = String.from_utf16(ptr.as(UInt16*))
              str
            ensure
              LibKernel32Clip.global_unlock(mem)
            end
          ensure
            LibUser32Clip.close_clipboard
          end
        {% else %}
          raise NotImplementedError.new("Lune::Native::Clipboard.read — use the capability's DEFAULT_READ on non-Windows platforms")
        {% end %}
      end

      def self.write(text : String) : Nil
        {% if flag?(:lune_native_test_mock) %}
          ClipboardMock.record_write(text)
        {% elsif flag?(:win32) %}
          # CF_UNICODETEXT is UTF-16LE, null-terminated. Allocate (chars+1)*2
          # bytes of moveable global memory, copy the UTF-16 code units, then
          # hand it off via SetClipboardData (which takes ownership on success).
          utf16 = text.to_utf16
          byte_size = LibC::SizeT.new((utf16.size + 1) * 2)
          return if LibUser32Clip.open_clipboard(Pointer(Void).null) == 0
          begin
            LibUser32Clip.empty_clipboard
            mem = LibKernel32Clip.global_alloc(LibKernel32Clip::GMEM_MOVEABLE, byte_size)
            return if mem.null?
            ptr = LibKernel32Clip.global_lock(mem)
            return if ptr.null?
            dst = ptr.as(UInt16*)
            utf16.size.times { |i| dst[i] = utf16[i] }
            dst[utf16.size] = 0_u16
            LibKernel32Clip.global_unlock(mem)
            LibUser32Clip.set_clipboard_data(LibUser32Clip::CF_UNICODETEXT, mem)
          ensure
            LibUser32Clip.close_clipboard
          end
          nil
        {% else %}
          raise NotImplementedError.new("Lune::Native::Clipboard.write — use the capability's DEFAULT_WRITE on non-Windows platforms")
        {% end %}
      end

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
          return "" if LibUser32Clip.open_clipboard(Pointer(Void).null) == 0
          begin
            mem = LibUser32Clip.get_clipboard_data(cf_html)
            return "" if mem.null?
            ptr = LibKernel32Clip.global_lock(mem)
            return "" if ptr.null?
            begin
              size = LibKernel32Clip.global_size(mem).to_i
              raw = String.new(Slice.new(ptr.as(UInt8*), size))
              unwrap_cf_html(raw)
            ensure
              LibKernel32Clip.global_unlock(mem)
            end
          ensure
            LibUser32Clip.close_clipboard
          end
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
          payload = wrap_cf_html(html)
          bytes = payload.to_slice
          return if LibUser32Clip.open_clipboard(Pointer(Void).null) == 0
          begin
            LibUser32Clip.empty_clipboard
            # SetClipboardData takes ownership of the HGLOBAL on success.
            # +1 for the trailing null byte — CF_HTML is a UTF-8 byte stream.
            mem = LibKernel32Clip.global_alloc(LibKernel32Clip::GMEM_MOVEABLE, LibC::SizeT.new(bytes.size + 1))
            return if mem.null?
            ptr = LibKernel32Clip.global_lock(mem)
            return if ptr.null?
            bytes.copy_to(Slice.new(ptr.as(UInt8*), bytes.size))
            ptr.as(UInt8*)[bytes.size] = 0_u8
            LibKernel32Clip.global_unlock(mem)
            LibUser32Clip.set_clipboard_data(cf_html, mem)
          ensure
            LibUser32Clip.close_clipboard
          end
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
