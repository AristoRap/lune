{% if flag?(:win32) && !flag?(:lune_native_test_mock) %}
  module Lune
    module Native
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

      module Clipboard
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
          start_html = header_size
          start_fragment = start_html + prefix.bytesize
          end_fragment = start_fragment + html.bytesize
          end_html = end_fragment + suffix.bytesize
          header = header_template % {start_html, end_html, start_fragment, end_fragment}
          "#{header}#{prefix}#{html}#{suffix}"
        end

        # Strip the CF_HTML envelope and return just the user-visible fragment.
        private def self.unwrap_cf_html(raw : String) : String
          start_marker = "<!--StartFragment-->"
          end_marker = "<!--EndFragment-->"
          si = raw.index(start_marker)
          ei = raw.index(end_marker)
          return raw unless si && ei && ei > si
          raw[(si + start_marker.bytesize)...ei]
        end

        # Plaintext read goes straight to Win32 CF_UNICODETEXT — the
        # previous PowerShell shellout took ~200-500ms cold-start and (worse)
        # blew up with "Concurrency is disabled in isolated contexts" because
        # Process.run spawns a wait fiber that can't be scheduled on the webview
        # Isolated thread.
        def self.read : String
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
        end

        def self.write(text : String) : Nil
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
        end

        def self.read_html : String
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
        end

        def self.write_html(html : String) : Nil
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
        end

        # PNG ↔ CF_DIB conversion via PowerShell + System.Drawing.Bitmap.
        # Same shellout pattern as Native::Notifications: the WIC / direct-
        # CF_DIB path would need a few hundred lines of COM bindings, and
        # image clipboard ops are infrequent enough that the ~200 ms cost is
        # acceptable. The plugin's bindings are marked `async: true` so the
        # call doesn't block the webview's Isolated fiber.
        def self.read_image : String
          script = <<-PS
            Add-Type -AssemblyName System.Windows.Forms | Out-Null
            Add-Type -AssemblyName System.Drawing | Out-Null
            $img = [System.Windows.Forms.Clipboard]::GetImage()
            if ($img -eq $null) { Write-Output ""; exit 0 }
            $ms = New-Object System.IO.MemoryStream
            $img.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
            [System.Convert]::ToBase64String($ms.ToArray())
          PS
          stdout = IO::Memory.new
          stderr = IO::Memory.new
          status = Process.run("powershell",
            ["-NoProfile", "-Sta", "-WindowStyle", "Hidden", "-Command", script],
            input: Process::Redirect::Close,
            output: stdout,
            error: stderr)
          unless status.success?
            Lune.logger.warn { "Clipboard.read_image: powershell exited #{status.exit_code? || -1}: #{stderr.to_s.strip}" }
            return ""
          end
          b64 = stdout.to_s.strip
          b64.empty? ? "" : "data:image/png;base64,#{b64}"
        end

        def self.write_image(data_url : String) : Nil
          b64 = strip_data_url_prefix(data_url)
          return if b64.empty?
          script = <<-PS
            Add-Type -AssemblyName System.Windows.Forms | Out-Null
            Add-Type -AssemblyName System.Drawing | Out-Null
            $bytes = [System.Convert]::FromBase64String($env:LUNE_CLIPBOARD_IMAGE_B64)
            $ms = New-Object System.IO.MemoryStream(,$bytes)
            $img = [System.Drawing.Image]::FromStream($ms)
            [System.Windows.Forms.Clipboard]::SetImage($img)
          PS
          stderr = IO::Memory.new
          status = Process.run("powershell",
            ["-NoProfile", "-Sta", "-WindowStyle", "Hidden", "-Command", script],
            env: {"LUNE_CLIPBOARD_IMAGE_B64" => b64},
            input: Process::Redirect::Close,
            output: Process::Redirect::Close,
            error: stderr)
          unless status.success?
            Lune.logger.warn { "Clipboard.write_image: powershell exited #{status.exit_code? || -1}: #{stderr.to_s.strip}" }
          end
          nil
        end

        # "data:image/png;base64,XXXX" → "XXXX". Pass-through if the caller
        # already gave us raw base64.
        private def self.strip_data_url_prefix(s : String) : String
          if s.starts_with?("data:")
            comma = s.index(',')
            comma ? s[(comma + 1)..] : ""
          else
            s
          end
        end
      end
    end
  end
{% end %}
