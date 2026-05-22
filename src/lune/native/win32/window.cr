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

        WM_DESTROY = 0x0002_u32
        WM_CLOSE   = 0x0010_u32

        GWLP_WNDPROC = -4

        fun is_window = IsWindow(hwnd : Void*) : LibC::Int
        fun get_window_rect = GetWindowRect(hwnd : Void*, rect : Rect*) : LibC::Int
        fun move_window = MoveWindow(hwnd : Void*, x : LibC::Int, y : LibC::Int, w : LibC::Int, h : LibC::Int, repaint : LibC::Int) : LibC::Int
        fun set_window_text_w = SetWindowTextW(hwnd : Void*, text : UInt16*) : LibC::Int
        fun show_window = ShowWindow(hwnd : Void*, cmd : LibC::Int) : LibC::Int
        fun set_window_pos = SetWindowPos(hwnd : Void*, after : Void*, x : LibC::Int, y : LibC::Int, w : LibC::Int, h : LibC::Int, flags : UInt32) : LibC::Int
        fun get_system_metrics = GetSystemMetrics(index : LibC::Int) : LibC::Int
        fun post_message_w = PostMessageW(hwnd : Void*, msg : UInt32, wparam : LibC::UIntPtrT, lparam : LibC::IntPtrT) : LibC::Int
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
        # Win32 silently no-ops to preserve a uniform API.
        def self.set_titlebar_transparent(handle : Void*, full_size_content : Bool); end
        def self.set_background_transparent(handle : Void*); end
        def self.setup_drag_monitor; end
        def self.start_window_drag(handle : Void*); end
        def self.hide_title(handle : Void*); end
        def self.hide_traffic_lights(handle : Void*); end
        def self.set_appearance(handle : Void*, mode : Int32); end
        def self.set_content_protection(handle : Void*, enabled : Bool); end
        def self.set_always_on_top(handle : Void*, enabled : Bool); end
        def self.set_activation_policy_accessory; end
        def self.hide(handle : Void*); end
        def self.show(handle : Void*); end

        def self.visible?(handle : Void*) : Bool
          true
        end

        def self.auto_hide_on_resign_key(handle : Void*); end

        # PostMessage(WM_CLOSE) lets the existing WNDPROC chain destroy the
        # window normally (webview shard cleanup + our subclassed on_close trap
        # both still fire). Matches `[NSWindow close]` semantics on darwin.
        def self.close(handle : Void*)
          LibUser32.post_message_w(handle, LibUser32::WM_CLOSE, LibC::UIntPtrT.new(0), LibC::IntPtrT.new(0))
        end

        # Map HWND → user block + previous WNDPROC. Accessed only from the UI
        # thread (on_close is called inside main_wv.dispatch; the subclassed
        # WNDPROC runs on the same message-pump thread).
        @@close_procs = {} of Void* => Proc(Nil)
        @@prev_wndprocs = {} of Void* => Void*

        # Subclass the HWND to trap WM_DESTROY and invoke the block. Mirrors
        # darwin's NSWindowWillCloseNotification observer (fires for both
        # programmatic close and user-clicked X).
        def self.on_close(handle : Void*, &block : ->) : Nil
          @@close_procs[handle] = block

          new_proc = ->Window.lune_wndproc(Void*, UInt32, LibC::UIntPtrT, LibC::IntPtrT)
          new_addr = LibC::IntPtrT.new!(new_proc.pointer.address)
          prev_addr = LibUser32.set_window_long_ptr_w(handle, LibUser32::GWLP_WNDPROC, new_addr)
          @@prev_wndprocs[handle] = Pointer(Void).new(prev_addr.to_u64!) if prev_addr != 0
        end

        # Static WNDPROC: forward every message to the shard's original proc,
        # but on WM_DESTROY first invoke the user's block (HWND still valid).
        def self.lune_wndproc(hwnd : Void*, msg : UInt32, wparam : LibC::UIntPtrT, lparam : LibC::IntPtrT) : LibC::IntPtrT
          if msg == LibUser32::WM_DESTROY
            if block = @@close_procs.delete(hwnd)
              block.call
            end
          end

          result = if prev = @@prev_wndprocs[hwnd]?
                     LibUser32.call_window_proc_w(prev, hwnd, msg, wparam, lparam)
                   else
                     LibUser32.def_window_proc_w(hwnd, msg, wparam, lparam)
                   end

          @@prev_wndprocs.delete(hwnd) if msg == LibUser32::WM_DESTROY
          result
        end
      end
    end
  end
{% end %}
