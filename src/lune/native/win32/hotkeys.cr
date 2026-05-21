{% if flag?(:win32) && !flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      # LibUser32Hotkeys also holds the canonical Msg struct + PeekMessageW
      # declaration. win32/tray.cr reuses both — Crystal would otherwise error
      # on a second `fun peek_message_w = PeekMessageW(...)` with different
      # types in a different lib.
      @[Link("user32")]
      lib LibUser32Hotkeys
        MOD_ALT     = 0x0001_u32
        MOD_CONTROL = 0x0002_u32
        MOD_SHIFT   = 0x0004_u32
        MOD_WIN     = 0x0008_u32

        WM_HOTKEY = 0x0312_u32
        PM_REMOVE = 0x0001_u32

        struct Point
          x : LibC::Long
          y : LibC::Long
        end

        struct Msg
          hwnd : Void*
          message : UInt32
          # WPARAM/LPARAM are UINT_PTR/LONG_PTR — 8 bytes on 64-bit Windows.
          # LibC::ULong is only 4 bytes (LLP64), so we use explicit 64-bit types.
          # UInt64 forces 8-byte alignment, which inserts the 4-byte padding at
          # offset 12 that the real MSG struct has, placing w_param at offset 16.
          w_param : UInt64
          l_param : Int64
          time : UInt32
          pt : Point
          # On modern Windows the struct includes a private DWORD too, but
          # PeekMessage doesn't read past `pt` so we keep the struct minimal.
        end

        fun register_hot_key = RegisterHotKey(hwnd : Void*, id : LibC::Int, fs_modifiers : UInt32, vk : UInt32) : LibC::Int
        fun unregister_hot_key = UnregisterHotKey(hwnd : Void*, id : LibC::Int) : LibC::Int
        fun peek_message_w = PeekMessageW(msg : Msg*, hwnd : Void*, msg_filter_min : UInt32, msg_filter_max : UInt32, remove : UInt32) : LibC::Int
      end
    end
  end
{% end %}
