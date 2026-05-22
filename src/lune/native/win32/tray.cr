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

      module Tray
        # ── Win32 implementation internals ──────────────────────────────────
        # All HWND / Shell_NotifyIcon traffic runs on a single Isolated thread
        # ("lune-tray") that owns the message queue. Producer-side calls push
        # Win32Op records into @@win32_ops (Mutex-guarded); the pump drains
        # the ops queue and the WM queue on each 10 ms tick.

        WM_TRAY_CALLBACK = LibUser32Tray::WM_APP + 1_u32
        TRAY_ICON_ID     = 1_u32

        alias Win32MenuTuple = NamedTuple(id: String, label: String)
        record Win32Op,
          action : Symbol,
          reply : Channel(Bool),
          menu_items : Array(Win32MenuTuple) = [] of Win32MenuTuple,
          icon_path : String = ""

        @@win32_on_click : (-> Nil)? = nil
        @@win32_on_right_click : (-> Nil)? = nil
        @@win32_on_menu_click : (String -> Nil)? = nil
        @@win32_ops_mu = Mutex.new
        @@win32_ops = [] of Win32Op
        @@win32_started : Bool = false
        @@win32_hwnd : Void* = Pointer(Void).null
        @@win32_visible : Bool = false
        @@win32_menu : Void* = Pointer(Void).null
        @@win32_menu_ids = {} of UInt32 => String
        @@win32_pump_fiber : Fiber? = nil
        @@win32_h_icon : Void* = Pointer(Void).null
        @@win32_h_icon_owned : Bool = false
        @@win32_pending_destroy : Void* = Pointer(Void).null

        # WindowProc — invoked by DispatchMessageW on the pump thread. Pure
        # dispatcher; the actual handlers live in @@win32_on_click /
        # @@win32_on_right_click and run on the pump thread synchronously.
        WIN32_WND_PROC = ->(hwnd : Void*, msg : UInt32, w_param : UInt64, l_param : Int64) : Int64 {
          if msg == WM_TRAY_CALLBACK
            case l_param.to_u32
            when LibUser32Tray::WM_LBUTTONUP, LibUser32Tray::WM_LBUTTONDBLCLK
              @@win32_on_click.try(&.call)
            when LibUser32Tray::WM_RBUTTONUP
              @@win32_on_right_click.try(&.call)
            end
            return 0_i64
          end
          LibUser32Tray.def_window_proc_w(hwnd, msg, w_param, l_param)
        }

        WIN32_CLASS_NAME = "LuneTrayWindowClass"

        def self.show(icon_path : String = "", on_click : (-> Nil)? = nil)
          # icon_path is loaded by the pump via LoadImageW(LR_LOADFROMFILE)
          # — empty / missing / non-.ico falls back to IDI_APPLICATION (the
          # shared Windows default app icon) and logs a warning. macOS has
          # the same "empty → default" semantics (see ext/native/macos/tray.m).
          ensure_win32_pump
          @@win32_on_click = on_click
          op = Win32Op.new(:show, Channel(Bool).new(1), icon_path: icon_path)
          @@win32_ops_mu.synchronize { @@win32_ops << op }
          op.reply.receive
        end

        def self.hide
          return unless @@win32_started
          op = Win32Op.new(:hide, Channel(Bool).new(1))
          @@win32_ops_mu.synchronize { @@win32_ops << op }
          op.reply.receive
        end

        def self.set_icon(icon_path : String)
          ensure_win32_pump
          op = Win32Op.new(:set_icon, Channel(Bool).new(1), icon_path: icon_path)
          @@win32_ops_mu.synchronize { @@win32_ops << op }
          op.reply.receive
        end

        def self.button_screen_rect : {Int32, Int32, Int32, Int32}?
          nil
        end

        def self.set_right_click_cb(cb : (-> Nil)?)
          @@win32_on_right_click = cb
        end

        def self.popup_menu : Nil
          return unless @@win32_started
          # If we're already on the pump fiber (i.e. called from inside
          # WindowProc via @@win32_on_right_click), TrackPopupMenu has to run
          # inline — dispatching an op and awaiting reply would self-deadlock
          # since the pump can't drain ops while we hold its fiber. From any
          # other fiber, route through the op queue.
          if Fiber.current == @@win32_pump_fiber
            perform_popup_menu_win32
          else
            op = Win32Op.new(:popup_menu, Channel(Bool).new(1))
            @@win32_ops_mu.synchronize { @@win32_ops << op }
            op.reply.receive
          end
        end

        def self.set_menu(items : Array({id: String, label: String}), on_menu_click : (String -> Nil)? = nil)
          @@has_menu = items.any?
          ensure_win32_pump
          @@win32_on_menu_click = on_menu_click
          # `items` is Array(NamedTuple(id, label)); the Op carries a copy so
          # the pump thread sees a stable snapshot even if the producer mutates.
          op_items = items.map { |i| {id: i[:id], label: i[:label]} }
          if Fiber.current == @@win32_pump_fiber
            perform_set_menu_win32(op_items)
          else
            op = Win32Op.new(:set_menu, Channel(Bool).new(1), op_items)
            @@win32_ops_mu.synchronize { @@win32_ops << op }
            op.reply.receive
          end
        end

        private def self.win32_wstr(s : String) : UInt16*
          arr = s.to_utf16
          buf = Pointer(UInt16).malloc(arr.size + 1)
          arr.size.times { |i| buf[i] = arr[i] }
          buf[arr.size] = 0_u16
          buf
        end

        private def self.ensure_win32_pump : Nil
          return if @@win32_started
          ready = Channel(Nil).new(1)

          Fiber::ExecutionContext::Isolated.new("lune-tray") do
            @@win32_pump_fiber = Fiber.current
            h_inst = LibKernel32Tray.get_module_handle_w(Pointer(UInt16).null)
            class_name_w = win32_wstr(WIN32_CLASS_NAME)

            wc = LibUser32Tray::WndClassExW.new
            wc.cb_size = sizeof(LibUser32Tray::WndClassExW).to_u32
            wc.lpfn_wnd_proc = WIN32_WND_PROC
            wc.h_instance = h_inst
            wc.lpsz_class_name = class_name_w
            # Ignore the return value: registering twice across a hot-reload
            # returns 0 + ERROR_CLASS_ALREADY_EXISTS, which is harmless — the
            # existing registration is still valid.
            LibUser32Tray.register_class_ex_w(pointerof(wc))

            @@win32_hwnd = LibUser32Tray.create_window_ex_w(
              0_u32,
              class_name_w,
              Pointer(UInt16).null,
              0_u32, 0, 0, 0, 0,
              Pointer(Void).new(LibUser32Tray::HWND_MESSAGE),
              Pointer(Void).null,
              h_inst,
              Pointer(Void).null,
            )

            ready.send(nil)

            msg = LibUser32Hotkeys::Msg.new
            loop do
              # 1. Drain queued ops.
              ops = @@win32_ops_mu.synchronize { o = @@win32_ops.dup; @@win32_ops.clear; o }
              ops.each { |op| process_win32_op(op) }

              # 2. Drain WM messages — DispatchMessageW invokes WIN32_WND_PROC
              # for any WM_TRAY_CALLBACK posted by Shell_NotifyIcon.
              while LibUser32Hotkeys.peek_message_w(pointerof(msg), Pointer(Void).null,
                      0_u32, 0_u32, LibUser32Hotkeys::PM_REMOVE) != 0
                LibUser32Tray.translate_message(pointerof(msg))
                LibUser32Tray.dispatch_message_w(pointerof(msg))
              end

              sleep 10.milliseconds
            end
          end

          ready.receive
          @@win32_started = true
        end

        private def self.build_win32_nid : LibShell32Tray::NotifyIconDataW
          nid = LibShell32Tray::NotifyIconDataW.new
          nid.cb_size = sizeof(LibShell32Tray::NotifyIconDataW).to_u32
          nid.h_wnd = @@win32_hwnd
          nid.u_id = TRAY_ICON_ID
          nid.u_flags = LibShell32Tray::NIF_MESSAGE | LibShell32Tray::NIF_ICON
          nid.u_callback_message = WM_TRAY_CALLBACK
          # Lazy init: first call falls back to the shared system app icon if
          # no custom .ico has been set yet. LoadIconW returns a shared HICON
          # (no DestroyIcon needed), so we leave @@win32_h_icon_owned false.
          if @@win32_h_icon.null?
            @@win32_h_icon = LibUser32Tray.load_icon_w(Pointer(Void).null, LibUser32Tray::IDI_APPLICATION)
            @@win32_h_icon_owned = false
          end
          nid.h_icon = @@win32_h_icon
          nid
        end

        # Try to load `path` as a Win32 .ico file. Returns the HICON on
        # success, or Pointer(Void).null (with a warning logged) when the
        # path is empty / missing / not .ico / fails to parse. Runs on the
        # pump thread; the LoadImageW + GetSystemMetrics calls are thread-
        # safe Win32 APIs that don't require HWND ownership.
        private def self.load_win32_icon_file(path : String) : Void*
          return Pointer(Void).null if path.empty?
          unless File.exists?(path)
            Lune.logger.warn { "Lune::Native::Tray: icon file not found: #{path} — using default Windows app icon" }
            return Pointer(Void).null
          end
          unless path.downcase.ends_with?(".ico")
            Lune.logger.warn { "Lune::Native::Tray: only .ico files are supported on Win32 (got #{path}) — using default Windows app icon" }
            return Pointer(Void).null
          end
          path_w = win32_wstr(path)
          cx = LibUser32Tray.get_system_metrics(LibUser32Tray::SM_CXSMICON)
          cy = LibUser32Tray.get_system_metrics(LibUser32Tray::SM_CYSMICON)
          icon = LibUser32Tray.load_image_w(Pointer(Void).null, path_w,
            LibUser32Tray::IMAGE_ICON, cx, cy, LibUser32Tray::LR_LOADFROMFILE)
          if icon.null?
            Lune.logger.warn { "Lune::Native::Tray: LoadImageW failed for #{path} — using default Windows app icon" }
            return Pointer(Void).null
          end
          icon
        end

        # Swap @@win32_h_icon to a new HICON (loaded from `path`, or shared
        # IDI_APPLICATION on fallback). Stashes the previous owned HICON in
        # @@win32_pending_destroy — the CALLER must invoke destroy_pending_
        # win32_icon AFTER the next Shell_NotifyIcon call so Windows is no
        # longer referencing the old icon.
        private def self.set_win32_icon(path : String) : Nil
          loaded = load_win32_icon_file(path)
          if loaded.null?
            new_icon = LibUser32Tray.load_icon_w(Pointer(Void).null, LibUser32Tray::IDI_APPLICATION)
            new_owned = false
          else
            new_icon = loaded
            new_owned = true
          end

          if @@win32_h_icon_owned && !@@win32_h_icon.null?
            @@win32_pending_destroy = @@win32_h_icon
          end
          @@win32_h_icon = new_icon
          @@win32_h_icon_owned = new_owned
        end

        # Release the previous HICON, if any. Safe to call unconditionally;
        # no-op when nothing is pending. Must be called AFTER Shell_NotifyIcon
        # has switched to the new HICON.
        private def self.destroy_pending_win32_icon : Nil
          return if @@win32_pending_destroy.null?
          LibUser32Tray.destroy_icon(@@win32_pending_destroy)
          @@win32_pending_destroy = Pointer(Void).null
        end

        # Runs on the pump thread only.
        private def self.process_win32_op(op : Win32Op) : Nil
          case op.action
          when :show
            set_win32_icon(op.icon_path)
            nid = build_win32_nid
            cmd = @@win32_visible ? LibShell32Tray::NIM_MODIFY : LibShell32Tray::NIM_ADD
            ok = LibShell32Tray.shell_notify_icon_w(cmd, pointerof(nid)) != 0
            @@win32_visible = true if ok
            destroy_pending_win32_icon
            op.reply.send(ok)
          when :hide
            if @@win32_visible
              nid = build_win32_nid
              LibShell32Tray.shell_notify_icon_w(LibShell32Tray::NIM_DELETE, pointerof(nid))
              @@win32_visible = false
            end
            op.reply.send(true)
          when :set_icon
            set_win32_icon(op.icon_path)
            if @@win32_visible
              nid = build_win32_nid
              LibShell32Tray.shell_notify_icon_w(LibShell32Tray::NIM_MODIFY, pointerof(nid))
            end
            destroy_pending_win32_icon
            op.reply.send(true)
          when :set_menu
            perform_set_menu_win32(op.menu_items)
            op.reply.send(true)
          when :popup_menu
            perform_popup_menu_win32
            op.reply.send(true)
          end
        end

        # Tear down any existing HMENU and rebuild from `items`. Empty list →
        # menu cleared, @@win32_menu becomes null. Always runs on the pump
        # thread so HMENU mutations are race-free.
        private def self.perform_set_menu_win32(items : Array(Win32MenuTuple)) : Nil
          unless @@win32_menu.null?
            LibUser32Menu.destroy_menu(@@win32_menu)
            @@win32_menu = Pointer(Void).null
          end
          @@win32_menu_ids.clear
          return if items.empty?

          menu = LibUser32Menu.create_popup_menu
          return if menu.null?

          cmd : UInt32 = 1_u32
          items.each do |item|
            if item[:id] == "---"
              LibUser32Menu.append_menu_w(menu, LibUser32Menu::MF_SEPARATOR, 0_u64, Pointer(UInt16).null)
            else
              label_w = win32_wstr(item[:label])
              LibUser32Menu.append_menu_w(menu, LibUser32Menu::MF_STRING, cmd.to_u64, label_w)
              @@win32_menu_ids[cmd] = item[:id]
              cmd += 1_u32
            end
          end
          @@win32_menu = menu
        end

        # Pop the current HMENU at the cursor. Must run on the thread that
        # owns @@win32_hwnd (= the pump thread). Blocks until the menu is
        # dismissed. The selected command ID is mapped back to the user's
        # string id via @@win32_menu_ids and dispatched to @@win32_on_menu_click.
        private def self.perform_popup_menu_win32 : Nil
          return if @@win32_menu.null? || @@win32_hwnd.null?

          pt = LibUser32Menu::Point.new
          LibUser32Tray.get_cursor_pos(pointerof(pt))

          # MSDN: owner window must be foreground for the menu to dismiss
          # correctly on outside clicks. We use our message-only HWND as the
          # owner — invisible but valid for menu ownership.
          LibUser32Menu.set_foreground_window(@@win32_hwnd)
          chosen = LibUser32Menu.track_popup_menu(@@win32_menu,
            LibUser32Menu::TPM_RETURNCMD | LibUser32Menu::TPM_RIGHTBUTTON,
            pt.x.to_i32, pt.y.to_i32, 0, @@win32_hwnd, Pointer(Void).null)
          # Defeat the "menu won't dismiss on the next off-click" quirk.
          LibUser32Tray.post_message_w(@@win32_hwnd, 0_u32, 0_u64, 0_i64)

          if chosen != 0
            if id = @@win32_menu_ids[chosen.to_u32]?
              @@win32_on_menu_click.try(&.call(id))
            end
          end
        end
      end
    end
  end
{% end %}
