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
        SW_SHOW       = 5
        SW_MINIMIZE   = 6
        SW_RESTORE    = 9

        SWP_NOSIZE   = 0x0001_u32
        SWP_NOZORDER = 0x0004_u32

        SM_CXSCREEN = 0
        SM_CYSCREEN = 1

        WM_DESTROY       = 0x0002_u32
        WM_CLOSE         = 0x0010_u32
        WM_COMMAND       = 0x0111_u32
        WM_NCLBUTTONDOWN = 0x00A1_u32

        HTCAPTION = 2_u64

        GWLP_WNDPROC = -4

        fun is_window = IsWindow(hwnd : Void*) : LibC::Int
        fun is_window_visible = IsWindowVisible(hwnd : Void*) : LibC::Int
        fun set_foreground_window = SetForegroundWindow(hwnd : Void*) : LibC::Int
        fun get_window_rect = GetWindowRect(hwnd : Void*, rect : Rect*) : LibC::Int
        fun move_window = MoveWindow(hwnd : Void*, x : LibC::Int, y : LibC::Int, w : LibC::Int, h : LibC::Int, repaint : LibC::Int) : LibC::Int
        fun set_window_text_w = SetWindowTextW(hwnd : Void*, text : UInt16*) : LibC::Int
        fun show_window = ShowWindow(hwnd : Void*, cmd : LibC::Int) : LibC::Int
        fun set_window_pos = SetWindowPos(hwnd : Void*, after : Void*, x : LibC::Int, y : LibC::Int, w : LibC::Int, h : LibC::Int, flags : UInt32) : LibC::Int
        fun get_system_metrics = GetSystemMetrics(index : LibC::Int) : LibC::Int
        fun post_message_w = PostMessageW(hwnd : Void*, msg : UInt32, wparam : LibC::UIntPtrT, lparam : LibC::IntPtrT) : LibC::Int
        fun send_message_w = SendMessageW(hwnd : Void*, msg : UInt32, wparam : LibC::UIntPtrT, lparam : LibC::IntPtrT) : LibC::IntPtrT
        fun release_capture = ReleaseCapture : LibC::Int
        fun set_window_long_ptr_w = SetWindowLongPtrW(hwnd : Void*, idx : LibC::Int, new_long : LibC::IntPtrT) : LibC::IntPtrT
        fun call_window_proc_w = CallWindowProcW(prev_proc : Void*, hwnd : Void*, msg : UInt32, wparam : LibC::UIntPtrT, lparam : LibC::IntPtrT) : LibC::IntPtrT
        fun def_window_proc_w = DefWindowProcW(hwnd : Void*, msg : UInt32, wparam : LibC::UIntPtrT, lparam : LibC::IntPtrT) : LibC::IntPtrT
      end

      module Window
        # Pack a Crystal String into a heap-allocated null-terminated UTF-16
        # buffer for Win32 W-suffix APIs.
        private def self.to_wstr(s : String) : UInt16*
          arr = s.to_utf16
          buf = Pointer(UInt16).malloc(arr.size + 1)
          arr.size.times { |i| buf[i] = arr[i] }
          buf[arr.size] = 0_u16
          buf
        end

        def self.disable_webview_drop(handle : Void*)
          raise NotImplementedError.new("Lune::Native::Window.disable_webview_drop is not implemented on Windows yet (v0.10.0 backlog)")
        end

        def self.setup_file_drop(handle : Void*,
                                 on_drop : (Int32, Int32, Array(String)) -> Nil,
                                 on_pos : (Int32, Int32) -> Nil,
                                 drag_pos_fn : String? = nil,
                                 drop_check_fn : String? = nil)
          raise NotImplementedError.new("Lune::Native::Window.setup_file_drop is not implemented on Windows yet (v0.10.0 backlog)")
        end

        # Darwin-only — Win32 has no NSDraggingSource equivalent today.
        def self.start_drag_out(handle : Void*, paths : Array(String)); end

        def self.minimize(handle : Void*)
          LibUser32.show_window(handle, LibUser32::SW_MINIMIZE)
        end

        def self.maximize(handle : Void*)
          LibUser32.show_window(handle, LibUser32::SW_MAXIMIZE)
        end

        def self.center(handle : Void*)
          rect = LibUser32::Rect.new
          LibUser32.get_window_rect(handle, pointerof(rect))
          w = (rect.right - rect.left).to_i32
          h = (rect.bottom - rect.top).to_i32
          sw = LibUser32.get_system_metrics(LibUser32::SM_CXSCREEN)
          sh = LibUser32.get_system_metrics(LibUser32::SM_CYSCREEN)
          x = ((sw - w) // 2).to_i32
          y = ((sh - h) // 2).to_i32
          LibUser32.set_window_pos(handle, Pointer(Void).null, x, y, 0, 0,
            LibUser32::SWP_NOSIZE | LibUser32::SWP_NOZORDER)
        end

        def self.set_title(handle : Void*, title : String)
          LibUser32.set_window_text_w(handle, to_wstr(title))
        end

        def self.set_size(handle : Void*, width : Int32, height : Int32)
          # Preserve current position; only resize.
          rect = LibUser32::Rect.new
          LibUser32.get_window_rect(handle, pointerof(rect))
          LibUser32.move_window(handle, rect.left.to_i32, rect.top.to_i32, width, height, 1)
        end

        def self.get_frame(handle : Void*) : {Int32, Int32, Int32, Int32}
          rect = LibUser32::Rect.new
          LibUser32.get_window_rect(handle, pointerof(rect))
          {rect.left.to_i32, rect.top.to_i32,
           (rect.right - rect.left).to_i32, (rect.bottom - rect.top).to_i32}
        end

        # True iff the handle still refers to a live OS window. Used by the
        # Windows WindowState tracker to self-terminate once webview_destroy has
        # invalidated the HWND.
        def self.alive?(handle : Void*) : Bool
          LibUser32.is_window(handle) != 0
        end

        def self.set_frame(handle : Void*, x : Int32, y : Int32, width : Int32, height : Int32)
          LibUser32.move_window(handle, x, y, width, height, 1)
        end

        # All of these are darwin-specific (NSWindow / NSApplication vocabulary);
        # Win32 silently does nothing to preserve a uniform API.
        def self.set_titlebar_transparent(handle : Void*, full_size_content : Bool); end
        def self.set_background_transparent(handle : Void*); end
        def self.setup_drag_monitor; end

        # CSS-driven window drag. Called from the `mousedown`-bound JS binding
        # while the left button is still down. The Win32 idiom:
        #   ReleaseCapture()                              # free WebView2's grab
        #   SendMessage(WM_NCLBUTTONDOWN, HTCAPTION, 0)   # enter the modal move loop
        # The OS handles the actual drag until WM_LBUTTONUP. SendMessage blocks
        # the calling fiber until the move loop ends — acceptable because the
        # bridge dispatches each binding on its own fiber, so the UI thread is
        # not held up.
        def self.start_window_drag(handle : Void*)
          LibUser32.release_capture
          LibUser32.send_message_w(handle, LibUser32::WM_NCLBUTTONDOWN,
            LibC::UIntPtrT.new(LibUser32::HTCAPTION), LibC::IntPtrT.new(0))
        end
        def self.hide_title(handle : Void*); end
        def self.hide_traffic_lights(handle : Void*); end
        def self.set_appearance(handle : Void*, mode : Int32); end
        def self.set_content_protection(handle : Void*, enabled : Bool); end
        def self.set_always_on_top(handle : Void*, enabled : Bool); end
        def self.set_activation_policy_accessory; end

        def self.hide(handle : Void*)
          LibUser32.show_window(handle, LibUser32::SW_HIDE)
        end

        def self.show(handle : Void*)
          LibUser32.show_window(handle, LibUser32::SW_SHOW)
          LibUser32.set_foreground_window(handle)
        end

        def self.visible?(handle : Void*) : Bool
          LibUser32.is_window_visible(handle) != 0
        end

        def self.auto_hide_on_resign_key(handle : Void*); end

        # PostMessage(WM_CLOSE) lets the existing WNDPROC chain destroy the
        # window normally (webview shard cleanup + our subclassed on_close trap
        # both still fire). Matches `[NSWindow close]` semantics on darwin.
        def self.close(handle : Void*)
          LibUser32.post_message_w(handle, LibUser32::WM_CLOSE, LibC::UIntPtrT.new(0), LibC::IntPtrT.new(0))
        end

        # Per-HWND hook state. Accessed only from the UI thread — `on_close` is
        # called inside `main_wv.dispatch`, menu command handlers are
        # registered from the runner before the message pump starts, and the
        # subclassed WNDPROC runs on that pump thread.
        @@close_procs = {} of Void* => Proc(Nil)
        @@command_handlers = {} of Void* => Hash(UInt32, Proc(Nil))
        @@prev_wndprocs = {} of Void* => Void*

        # Idempotent WNDPROC subclass — both `on_close` and the menu's
        # WM_COMMAND wiring need the same trampoline, and subclassing twice
        # would store our own proc as the "previous", looping infinitely on
        # forward. Marker entry (key present, value possibly null) tells us
        # the subclass is already installed.
        private def self.ensure_subclassed(handle : Void*) : Nil
          return if @@prev_wndprocs.has_key?(handle)
          new_proc = ->Window.lune_wndproc(Void*, UInt32, LibC::UIntPtrT, LibC::IntPtrT)
          new_addr = LibC::IntPtrT.new!(new_proc.pointer.address)
          prev_addr = LibUser32.set_window_long_ptr_w(handle, LibUser32::GWLP_WNDPROC, new_addr)
          @@prev_wndprocs[handle] = Pointer(Void).new(prev_addr.to_u64!)
        end

        # Subclass the HWND to trap WM_DESTROY and invoke the block. Mirrors
        # darwin's NSWindowWillCloseNotification observer (fires for both
        # programmatic close and user-clicked X).
        def self.on_close(handle : Void*, &block : ->) : Nil
          @@close_procs[handle] = block
          ensure_subclassed(handle)
        end

        # Register a menu/accelerator command handler for `cmd_id` on `handle`.
        # Called by `Native::Menu.set_from_options` after `AppendMenuW`-ing
        # each clickable item with its allocated ID. The WNDPROC trampoline
        # routes WM_COMMAND with HIWORD(wparam)=0 (menu) to the matching block.
        def self.register_command_handler(handle : Void*, cmd_id : UInt32, &block : ->) : Nil
          (@@command_handlers[handle] ||= {} of UInt32 => Proc(Nil))[cmd_id] = block
          ensure_subclassed(handle)
        end

        def self.clear_command_handlers(handle : Void*) : Nil
          @@command_handlers.delete(handle)
        end

        # Static WNDPROC: forward every message to the shard's original proc,
        # but trap WM_DESTROY for close hooks and WM_COMMAND (menu items) for
        # registered command handlers.
        def self.lune_wndproc(hwnd : Void*, msg : UInt32, wparam : LibC::UIntPtrT, lparam : LibC::IntPtrT) : LibC::IntPtrT
          case msg
          when LibUser32::WM_DESTROY
            if block = @@close_procs.delete(hwnd)
              block.call
            end
          when LibUser32::WM_COMMAND
            # HIWORD(wparam) == 0 → menu item; == 1 → accelerator. lparam is
            # the HMENU for menu, NULL for accelerator. We accept both shapes
            # so that a future accelerator-table commit reuses this dispatch
            # without further changes.
            notif = (wparam.to_u64 >> 16).to_u32
            if notif <= 1
              cmd_id = (wparam.to_u64 & 0xFFFF).to_u32
              if (hash = @@command_handlers[hwnd]?) && (handler = hash[cmd_id]?)
                handler.call
                return LibC::IntPtrT.new(0)
              end
            end
          end

          result = if prev = @@prev_wndprocs[hwnd]?
                     prev.null? ? LibUser32.def_window_proc_w(hwnd, msg, wparam, lparam) : LibUser32.call_window_proc_w(prev, hwnd, msg, wparam, lparam)
                   else
                     LibUser32.def_window_proc_w(hwnd, msg, wparam, lparam)
                   end

          if msg == LibUser32::WM_DESTROY
            @@prev_wndprocs.delete(hwnd)
            @@command_handlers.delete(hwnd)
          end
          result
        end
      end
    end
  end
{% end %}
