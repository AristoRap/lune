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
    end
  end
{% end %}
