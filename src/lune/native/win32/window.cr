{% if flag?(:win32) && !flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      # Win32 window basics use user32.dll directly — no .o shim needed. The
      # `handle : Void*` arg is the HWND returned by the webview shard via
      # `wv.native_handle(Webview::NativeHandleKind::UI_WINDOW)`.
      @[Link("user32")]
      lib LibUser32
        struct Rect
          left : LibC::Long
          top : LibC::Long
          right : LibC::Long
          bottom : LibC::Long
        end

        SW_HIDE       = 0
        SW_SHOWNORMAL = 1
        SW_MAXIMIZE   = 3
        SW_MINIMIZE   = 6
        SW_RESTORE    = 9

        SWP_NOSIZE   = 0x0001_u32
        SWP_NOZORDER = 0x0004_u32

        SM_CXSCREEN = 0
        SM_CYSCREEN = 1

        fun is_window = IsWindow(hwnd : Void*) : LibC::Int
        fun get_window_rect = GetWindowRect(hwnd : Void*, rect : Rect*) : LibC::Int
        fun move_window = MoveWindow(hwnd : Void*, x : LibC::Int, y : LibC::Int, w : LibC::Int, h : LibC::Int, repaint : LibC::Int) : LibC::Int
        fun set_window_text_w = SetWindowTextW(hwnd : Void*, text : UInt16*) : LibC::Int
        fun show_window = ShowWindow(hwnd : Void*, cmd : LibC::Int) : LibC::Int
        fun set_window_pos = SetWindowPos(hwnd : Void*, after : Void*, x : LibC::Int, y : LibC::Int, w : LibC::Int, h : LibC::Int, flags : UInt32) : LibC::Int
        fun get_system_metrics = GetSystemMetrics(index : LibC::Int) : LibC::Int
      end
    end
  end
{% end %}
