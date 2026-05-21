{% if flag?(:win32) && !flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      @[Link("user32")]
      lib LibUser32Menu
        MF_STRING    = 0x0000_u32
        MF_SEPARATOR = 0x0800_u32
        MF_GRAYED    = 0x0001_u32
        MF_CHECKED   = 0x0008_u32

        TPM_RETURNCMD   = 0x0100_u32
        TPM_NONOTIFY    = 0x0080_u32
        TPM_RIGHTBUTTON = 0x0002_u32

        struct Point
          x : LibC::Long
          y : LibC::Long
        end

        fun create_popup_menu = CreatePopupMenu : Void*
        fun destroy_menu = DestroyMenu(menu : Void*) : LibC::Int
        fun append_menu_w = AppendMenuW(menu : Void*, flags : UInt32, id : LibC::ULong, item : UInt16*) : LibC::Int
        fun track_popup_menu = TrackPopupMenu(menu : Void*, flags : UInt32, x : LibC::Int, y : LibC::Int, reserved : LibC::Int, hwnd : Void*, rect : Void*) : LibC::Int
        fun client_to_screen = ClientToScreen(hwnd : Void*, pt : Point*) : LibC::Int
        fun set_foreground_window = SetForegroundWindow(hwnd : Void*) : LibC::Int
      end
    end
  end
{% end %}
