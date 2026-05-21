module Lune
  module Native
    # Platform lib blocks + mock live in sibling subdirs:
    #   - mock/tray.cr     TrayMock module
    #   - darwin/tray.cr   LibNativeTray (.m shim — NSStatusItem)
    #   - linux/tray.cr    LibNativeTray (GtkStatusIcon via .c shim)
    #   - win32/tray.cr    LibUser32Tray + LibKernel32Tray + LibShell32Tray
    # All Win32 plumbing (message-only HWND, Shell_NotifyIcon, op queue, pump
    # fiber) lives in this file's `{% if flag?(:win32) %}` block — only the
    # raw `lib` declarations move to win32/tray.cr.
    module Tray
      # Kept at class level so GC never collects boxed callbacks while the tray is live.
      @@box : Pointer(Void) = Pointer(Void).null
      @@menu_box : Pointer(Void) = Pointer(Void).null
      @@right_click_box : Pointer(Void) = Pointer(Void).null

      # Crystal-side mirror of the current menu count. Lets capability defaults
      # decide between popping the menu and emitting an event at click time.
      @@has_menu : Bool = false

      def self.has_menu? : Bool
        @@has_menu
      end

      def self.show(icon_path : String = "", on_click : (-> Nil)? = nil)
        {% if flag?(:lune_native_test_mock) %}
          TrayMock.record_show(icon_path, on_click)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          if cb = on_click
            @@box = Box.box(cb)
            LibNativeTray.tray_show(icon_path, ->(data : Void*) {
              return if data.null?
              Box(Proc(Nil)).unbox(data).call
            }, @@box)
          else
            LibNativeTray.tray_show(icon_path, ->(data : Void*) { }, Pointer(Void).null)
          end
        {% elsif flag?(:win32) %}
          # icon_path is loaded by the pump via LoadImageW(LR_LOADFROMFILE)
          # — empty / missing / non-.ico falls back to IDI_APPLICATION (the
          # shared Windows default app icon) and logs a warning. macOS has
          # the same "empty → default" semantics (see ext/native/macos/tray.m).
          ensure_win32_pump
          @@win32_on_click = on_click
          op = Win32Op.new(:show, Channel(Bool).new(1), icon_path: icon_path)
          @@win32_ops_mu.synchronize { @@win32_ops << op }
          op.reply.receive
        {% end %}
      end

      def self.hide
        {% if flag?(:lune_native_test_mock) %}
          TrayMock.record_hide
        {% elsif flag?(:darwin) || flag?(:linux) %}
          LibNativeTray.tray_hide
        {% elsif flag?(:win32) %}
          return unless @@win32_started
          op = Win32Op.new(:hide, Channel(Bool).new(1))
          @@win32_ops_mu.synchronize { @@win32_ops << op }
          op.reply.receive
        {% end %}
      end

      def self.set_icon(icon_path : String)
        {% if flag?(:lune_native_test_mock) %}
          TrayMock.record_set_icon(icon_path)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          LibNativeTray.tray_set_icon(icon_path)
        {% elsif flag?(:win32) %}
          ensure_win32_pump
          op = Win32Op.new(:set_icon, Channel(Bool).new(1), icon_path: icon_path)
          @@win32_ops_mu.synchronize { @@win32_ops << op }
          op.reply.receive
        {% end %}
      end

      def self.button_screen_rect : {Int32, Int32, Int32, Int32}?
        {% if flag?(:lune_native_test_mock) %}
          TrayMock.mock_button_rect
        {% elsif flag?(:darwin) %}
          r = LibNativeTray.lune_tray_button_screen_rect
          return nil if r.width == 0 && r.height == 0
          {r.x.to_i32, r.y.to_i32, r.width.to_i32, r.height.to_i32}
        {% else %}
          nil
        {% end %}
      end

      def self.set_right_click_cb(cb : (-> Nil)?)
        {% if flag?(:lune_native_test_mock) %}
          # no-op in tests
        {% elsif flag?(:darwin) %}
          if cb
            @@right_click_box = Box.box(cb)
            LibNativeTray.lune_tray_set_right_click_cb(->(data : Void*) {
              return if data.null?
              Box(Proc(Nil)).unbox(data).call
            }, @@right_click_box)
          else
            LibNativeTray.lune_tray_set_right_click_cb(->(data : Void*) { }, Pointer(Void).null)
          end
        {% elsif flag?(:win32) %}
          @@win32_on_right_click = cb
        {% end %}
      end

      def self.popup_menu : Nil
        {% if flag?(:lune_native_test_mock) %}
          TrayMock.record_popup_menu
        {% elsif flag?(:darwin) %}
          LibNativeTray.tray_popup_menu
        {% elsif flag?(:win32) %}
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
        {% end %}
      end

      def self.set_menu(items : Array({id: String, label: String}), on_menu_click : (String -> Nil)? = nil)
        @@has_menu = items.any?
        {% if flag?(:lune_native_test_mock) %}
          TrayMock.record_set_menu(items, on_menu_click)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          ids = items.map { |i| i[:id].to_unsafe }
          labels = items.map { |i| i[:label].to_unsafe }
          if cb = on_menu_click
            @@menu_box = Box.box(cb)
            LibNativeTray.tray_set_menu(
              ids.to_unsafe, labels.to_unsafe, items.size,
              ->(id_ptr : LibC::Char*, data : Void*) {
                return if data.null?
                Box(Proc(String, Nil)).unbox(data).call(String.new(id_ptr))
              },
              @@menu_box
            )
          else
            LibNativeTray.tray_set_menu(
              ids.to_unsafe, labels.to_unsafe, items.size,
              ->(id_ptr : LibC::Char*, data : Void*) { },
              Pointer(Void).null
            )
          end
        {% elsif flag?(:win32) %}
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
        {% end %}
      end

      {% if flag?(:win32) %}
        # ── Win32 implementation internals ──────────────────────────────────
        # All HWND / Shell_NotifyIcon traffic runs on a single Isolated thread
        # ("lune-tray") that owns the message queue. Producer-side calls push
        # Win32Op records into @@win32_ops (Mutex-guarded); the pump drains
        # the ops queue and the WM queue on each 10 ms tick.

        WM_TRAY_CALLBACK = LibUser32Tray::WM_APP + 1_u32
        TRAY_ICON_ID     = 1_u32

        # Op carries either no extra data, the items array (set_menu), or the
        # icon path (show / set_icon). Crystal's `record` lets us default the
        # extra fields so the common call sites stay terse.
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
        # Identity of the pump fiber — set inside the Isolated block, used by
        # popup_menu to skip the op-queue dispatch when called from WindowProc
        # (also on this fiber, since DispatchMessageW invokes WindowProc).
        @@win32_pump_fiber : Fiber? = nil

        # Current HICON shown by Shell_NotifyIcon. @@win32_h_icon_owned tracks
        # whether we allocated this via LoadImageW (true → must DestroyIcon
        # when replaced) or got a shared system icon via LoadIconW (false →
        # never DestroyIcon — system icons are shared and outlive us).
        @@win32_h_icon : Void* = Pointer(Void).null
        @@win32_h_icon_owned : Bool = false
        # When set_win32_icon replaces an owned HICON, the old one can't be
        # destroyed immediately — Shell_NotifyIcon still references it until
        # the next NIM_MODIFY succeeds. We stash it here and destroy AFTER
        # the Shell_NotifyIcon call returns. Always Pointer(Void).null when
        # nothing is pending.
        @@win32_pending_destroy : Void* = Pointer(Void).null

        # WindowProc — invoked by DispatchMessageW on the pump thread. Pure
        # dispatcher; the actual handlers live in @@win32_on_click /
        # @@win32_on_right_click and run on the pump thread synchronously.
        # Returning 0 for handled messages, DefWindowProcW for everything
        # else (per Win32 convention).
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
      {% end %}
    end
  end
end
