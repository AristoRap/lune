{% if flag?(:win32) && !flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      # Win32 tray uses a dedicated Isolated thread that owns a hidden
      # message-only HWND. Shell_NotifyIconW is told to post WM_APP+1 to that
      # HWND on click; the WindowProc inspects lParam (WM_LBUTTONUP /
      # WM_RBUTTONUP) and dispatches to the Crystal click handlers directly.
      # Producer-side calls push Op records into a Mutex-guarded queue —
      # same pattern as Lune::Native::Hotkeys.
      #
      # LibUser32Tray reuses LibUser32Hotkeys::Msg / peek_message_w (declared
      # in win32/hotkeys.cr) — Crystal's `fun` system disallows two
      # declarations of the same C symbol with divergent types, and
      # PeekMessageW was declared first in hotkeys. Window-class plumbing
      # (register, create, dispatch) is unique to tray and lives here.
      @[Link("user32")]
      lib LibUser32Tray
        WM_APP           = 0x8000_u32
        WM_LBUTTONUP     = 0x0202_u32
        WM_LBUTTONDBLCLK = 0x0203_u32
        WM_RBUTTONUP     = 0x0205_u32

        # IDI_APPLICATION is a 16-bit MAKEINTRESOURCE ordinal; LoadIconW takes
        # it as an LPCWSTR but only the low word is used when the high word is
        # zero, so we pass it as a plain UInt64 via the function signature.
        IDI_APPLICATION = 32512_u64

        # Special parent value that flags CreateWindowExW to make a
        # message-only window (no UI, no paint, only message routing).
        # Encoded as (HWND)-3 — i.e. all-ones except the low 2 bits.
        HWND_MESSAGE = 0xFFFFFFFFFFFFFFFD_u64

        # LoadImageW type / flag constants used to load custom .ico files.
        IMAGE_ICON      =      1_u32
        LR_LOADFROMFILE = 0x0010_u32

        # GetSystemMetrics indices for the small (tray) icon dimensions —
        # DPI-aware on modern Windows when the process has the right manifest.
        SM_CXSMICON = 49_i32
        SM_CYSMICON = 50_i32

        struct WndClassExW
          cb_size : UInt32
          style : UInt32
          lpfn_wnd_proc : (Void*, UInt32, UInt64, Int64) -> Int64
          cb_cls_extra : LibC::Int
          cb_wnd_extra : LibC::Int
          h_instance : Void*
          h_icon : Void*
          h_cursor : Void*
          h_br_background : Void*
          lpsz_menu_name : UInt16*
          lpsz_class_name : UInt16*
          h_icon_sm : Void*
        end

        fun register_class_ex_w = RegisterClassExW(wc : WndClassExW*) : UInt16
        fun create_window_ex_w = CreateWindowExW(
          ex_style : UInt32, class_name : UInt16*, window_name : UInt16*,
          style : UInt32, x : LibC::Int, y : LibC::Int, w : LibC::Int, h : LibC::Int,
          parent : Void*, menu : Void*, h_instance : Void*, lp_param : Void*,
        ) : Void*
        fun destroy_window = DestroyWindow(hwnd : Void*) : LibC::Int
        fun def_window_proc_w = DefWindowProcW(hwnd : Void*, msg : UInt32, w : UInt64, l : Int64) : Int64
        fun translate_message = TranslateMessage(msg : LibUser32Hotkeys::Msg*) : LibC::Int
        fun dispatch_message_w = DispatchMessageW(msg : LibUser32Hotkeys::Msg*) : Int64
        fun load_icon_w = LoadIconW(h_instance : Void*, icon_name : UInt64) : Void*
        fun load_image_w = LoadImageW(h_instance : Void*, name : UInt16*, type : UInt32, cx : LibC::Int, cy : LibC::Int, fu_load : UInt32) : Void*
        fun destroy_icon = DestroyIcon(icon : Void*) : LibC::Int
        fun get_system_metrics = GetSystemMetrics(index : LibC::Int) : LibC::Int
        fun get_cursor_pos = GetCursorPos(pt : LibUser32Menu::Point*) : LibC::Int
        # PostMessageW(hwnd, WM_NULL, 0, 0) is the standard workaround for
        # TrackPopupMenu not dismissing cleanly on the first off-click — see
        # MSDN remarks. We post it right after TrackPopupMenu returns.
        fun post_message_w = PostMessageW(hwnd : Void*, msg : UInt32, w_param : UInt64, l_param : Int64) : LibC::Int
      end

      @[Link("kernel32")]
      lib LibKernel32Tray
        fun get_module_handle_w = GetModuleHandleW(name : UInt16*) : Void*
      end

      @[Link("shell32")]
      lib LibShell32Tray
        NIM_ADD    = 0x00000000_u32
        NIM_MODIFY = 0x00000001_u32
        NIM_DELETE = 0x00000002_u32

        NIF_MESSAGE = 0x00000001_u32
        NIF_ICON    = 0x00000002_u32
        NIF_TIP     = 0x00000004_u32

        # NOTIFYICONDATAW (x64 layout, 976 bytes). Crystal's natural-alignment
        # rules reproduce the C struct exactly: 4-byte pads land before h_wnd
        # (after cb_size) and before h_icon (after u_callback_message). The
        # union { uTimeout; uVersion } collapses to a single UInt32 — we never
        # use either field. guid_item is bytes (we never write it), and the
        # cumulative offset before it is already 8-aligned so no pad is needed.
        struct NotifyIconDataW
          cb_size : UInt32
          h_wnd : Void*
          u_id : UInt32
          u_flags : UInt32
          u_callback_message : UInt32
          h_icon : Void*
          sz_tip : UInt16[128]
          dw_state : UInt32
          dw_state_mask : UInt32
          sz_info : UInt16[256]
          u_version_or_timeout : UInt32
          sz_info_title : UInt16[64]
          dw_info_flags : UInt32
          guid_item : UInt8[16]
          h_balloon_icon : Void*
        end

        fun shell_notify_icon_w = Shell_NotifyIconW(message : UInt32, data : NotifyIconDataW*) : LibC::Int
      end
    end
  end
{% end %}
