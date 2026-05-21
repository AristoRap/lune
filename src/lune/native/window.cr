module Lune
  module Native
    # Platform lib blocks + mock live in sibling subdirs:
    #   - mock/window.cr     WindowMock module
    #   - darwin/window.cr   LibNativeWindow (NSWindow .m shim)
    #   - linux/window.cr    LibNativeWindow (GtkWindow .c shim)
    #   - win32/window.cr    LibUser32 (basic move/title/show — no .o shim)
    module Window
      # Keyed by window handle so multiple windows can each have a live drop callback
      # without one overwriting another's GC pin.
      @@drop_boxes = {} of Void* => Pointer(Void)
      @@drop_pos_boxes = {} of Void* => Pointer(Void)
      # Keyed by window handle; holds close procs until they fire (prevents GC).
      @@close_procs = {} of Void* => Proc(Nil)

      {% if flag?(:win32) %}
        # Pack a Crystal String into a heap-allocated null-terminated UTF-16
        # buffer for Win32 W-suffix APIs.
        private def self.to_wstr(s : String) : UInt16*
          arr = s.to_utf16
          buf = Pointer(UInt16).malloc(arr.size + 1)
          arr.size.times { |i| buf[i] = arr[i] }
          buf[arr.size] = 0_u16
          buf
        end
      {% end %}

      def self.disable_webview_drop(handle : Void*)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_disable_webview_drop
        {% elsif flag?(:darwin) || flag?(:linux) %}
          LibNativeWindow.disable_webview_drop(handle)
        {% elsif flag?(:win32) %}
          raise NotImplementedError.new("Lune::Native::Window.disable_webview_drop is not implemented on Windows yet (v0.10.0 backlog)")
        {% end %}
      end

      # on_drop       receives (x, y, paths) — coordinates in CSS pixels (origin top-left)
      # on_pos        receives (x, y) on each drag-move (Linux only; macOS uses drag_pos_fn)
      # drag_pos_fn   JS function name called natively on macOS, e.g. "window.__lune.dragPos"
      # drop_check_fn JS function name called natively on macOS on drop, e.g.
      #               "window.__lune.dropCheck" — fires synchronously from
      #               performDragOperation so it doesn't queue behind dragPos
      #               evals. Linux ignores this arg (no analogous mechanism today).
      def self.setup_file_drop(handle : Void*,
                               on_drop : (Int32, Int32, Array(String)) -> Nil,
                               on_pos : (Int32, Int32) -> Nil,
                               drag_pos_fn : String? = nil,
                               drop_check_fn : String? = nil)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_setup_file_drop(on_drop)
        {% elsif flag?(:darwin) %}
          @@drop_boxes[handle] = Box.box(on_drop)
          # on_pos is unused on macOS — the ObjC overlay calls evaluateJavaScript:
          # directly via drag_pos_fn, eliminating the double-async dispatch chain.
          LibNativeWindow.setup_file_drop(
            handle,
            ->(json_ptr : LibC::Char*, data : Void*) {
              return if data.null?
              begin
                parsed = JSON.parse(String.new(json_ptr))
                x = parsed["x"].as_i? || 0
                y = parsed["y"].as_i? || 0
                raw = parsed["paths"].as_a?
                paths = raw ? raw.compact_map(&.as_s?) : Array(String).new
                Box(Proc(Int32, Int32, Array(String), Nil)).unbox(data).call(x, y, paths)
              rescue JSON::ParseException | TypeCastError | KeyError
              end
            },
            @@drop_boxes[handle],
            drag_pos_fn ? drag_pos_fn.to_unsafe : Pointer(LibC::Char).null,
            drop_check_fn ? drop_check_fn.to_unsafe : Pointer(LibC::Char).null
          )
        {% elsif flag?(:linux) %}
          @@drop_boxes[handle] = Box.box(on_drop)
          @@drop_pos_boxes[handle] = Box.box(on_pos)
          LibNativeWindow.setup_file_drop(
            handle,
            ->(json_ptr : LibC::Char*, data : Void*) {
              return if data.null?
              begin
                parsed = JSON.parse(String.new(json_ptr))
                x = parsed["x"].as_i? || 0
                y = parsed["y"].as_i? || 0
                raw = parsed["paths"].as_a?
                paths = raw ? raw.compact_map(&.as_s?) : Array(String).new
                Box(Proc(Int32, Int32, Array(String), Nil)).unbox(data).call(x, y, paths)
              rescue JSON::ParseException | TypeCastError | KeyError
              end
            },
            @@drop_boxes[handle],
            ->(x : LibC::Int, y : LibC::Int, data : Void*) {
              return if data.null?
              Box(Proc(Int32, Int32, Nil)).unbox(data).call(x.to_i32, y.to_i32)
            },
            @@drop_pos_boxes[handle]
          )
        {% elsif flag?(:win32) %}
          raise NotImplementedError.new("Lune::Native::Window.setup_file_drop is not implemented on Windows yet (v0.10.0 backlog)")
        {% end %}
      end

      def self.start_drag_out(handle : Void*, paths : Array(String))
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_start_drag_out(paths)
        {% elsif flag?(:darwin) %}
          LibNativeWindow.lune_start_drag_out(handle, paths.to_json)
        {% end %}
      end

      def self.minimize(handle : Void*)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_minimize
        {% elsif flag?(:darwin) || flag?(:linux) %}
          LibNativeWindow.minimize(handle)
        {% elsif flag?(:win32) %}
          LibUser32.show_window(handle, LibUser32::SW_MINIMIZE)
        {% end %}
      end

      def self.maximize(handle : Void*)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_maximize
        {% elsif flag?(:darwin) || flag?(:linux) %}
          LibNativeWindow.maximize(handle)
        {% elsif flag?(:win32) %}
          LibUser32.show_window(handle, LibUser32::SW_MAXIMIZE)
        {% end %}
      end

      def self.center(handle : Void*)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_center
        {% elsif flag?(:darwin) || flag?(:linux) %}
          LibNativeWindow.center(handle)
        {% elsif flag?(:win32) %}
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
        {% end %}
      end

      def self.set_title(handle : Void*, title : String)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_set_title(title)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          LibNativeWindow.set_title(handle, title)
        {% elsif flag?(:win32) %}
          LibUser32.set_window_text_w(handle, to_wstr(title))
        {% end %}
      end

      def self.set_size(handle : Void*, width : Int32, height : Int32)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_set_size(width, height)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          LibNativeWindow.set_size(handle, width, height)
        {% elsif flag?(:win32) %}
          # Preserve current position; only resize.
          rect = LibUser32::Rect.new
          LibUser32.get_window_rect(handle, pointerof(rect))
          LibUser32.move_window(handle, rect.left.to_i32, rect.top.to_i32, width, height, 1)
        {% end %}
      end

      def self.get_frame(handle : Void*) : {Int32, Int32, Int32, Int32}
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.mock_frame
        {% elsif flag?(:darwin) || flag?(:linux) %}
          f = LibNativeWindow.get_frame(handle)
          {f.x.to_i32, f.y.to_i32, f.width.to_i32, f.height.to_i32}
        {% elsif flag?(:win32) %}
          rect = LibUser32::Rect.new
          LibUser32.get_window_rect(handle, pointerof(rect))
          {rect.left.to_i32, rect.top.to_i32,
           (rect.right - rect.left).to_i32, (rect.bottom - rect.top).to_i32}
        {% else %}
          {0, 0, 0, 0}
        {% end %}
      end

      # True iff the handle still refers to a live OS window. Used by the
      # Windows WindowState tracker to self-terminate once webview_destroy has
      # invalidated the HWND.
      def self.alive?(handle : Void*) : Bool
        {% if flag?(:lune_native_test_mock) %}
          true
        {% elsif flag?(:win32) %}
          LibUser32.is_window(handle) != 0
        {% else %}
          true
        {% end %}
      end

      def self.set_frame(handle : Void*, x : Int32, y : Int32, width : Int32, height : Int32)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_set_frame(x, y, width, height)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          LibNativeWindow.set_frame(handle, x, y, width, height)
        {% elsif flag?(:win32) %}
          LibUser32.move_window(handle, x, y, width, height, 1)
        {% end %}
      end

      def self.set_titlebar_transparent(handle : Void*, full_size_content : Bool)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_set_titlebar_transparent(full_size_content)
        {% elsif flag?(:darwin) %}
          LibNativeWindow.set_titlebar_transparent(handle, full_size_content ? 1 : 0)
        {% end %}
      end

      def self.set_background_transparent(handle : Void*)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_set_background_transparent
        {% elsif flag?(:darwin) %}
          LibNativeWindow.set_background_transparent(handle)
        {% end %}
      end

      def self.setup_drag_monitor
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_setup_drag_monitor
        {% elsif flag?(:darwin) %}
          LibNativeWindow.setup_drag_monitor
        {% end %}
      end

      def self.start_window_drag(handle : Void*)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_start_window_drag
        {% elsif flag?(:darwin) %}
          LibNativeWindow.start_window_drag(handle)
        {% end %}
      end

      def self.hide_title(handle : Void*)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_hide_title
        {% elsif flag?(:darwin) %}
          LibNativeWindow.hide_title(handle)
        {% end %}
      end

      def self.hide_traffic_lights(handle : Void*)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_hide_traffic_lights
        {% elsif flag?(:darwin) %}
          LibNativeWindow.hide_traffic_lights(handle)
        {% end %}
      end

      def self.set_appearance(handle : Void*, mode : Int32)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_set_appearance(mode)
        {% elsif flag?(:darwin) %}
          LibNativeWindow.set_appearance(handle, mode)
        {% end %}
      end

      def self.set_content_protection(handle : Void*, enabled : Bool)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_set_content_protection
        {% elsif flag?(:darwin) %}
          LibNativeWindow.set_content_protection(handle, enabled ? 1 : 0)
        {% end %}
      end

      def self.set_always_on_top(handle : Void*, enabled : Bool)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_set_always_on_top
        {% elsif flag?(:darwin) %}
          LibNativeWindow.set_always_on_top(handle, enabled ? 1 : 0)
        {% end %}
      end

      def self.close(handle : Void*)
        {% if !flag?(:lune_native_test_mock) && flag?(:darwin) %}
          LibNativeWindow.lune_window_close(handle)
        {% end %}
      end

      def self.set_activation_policy_accessory
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_set_activation_policy_accessory
        {% elsif flag?(:darwin) %}
          LibNativeWindow.lune_set_activation_policy_accessory
        {% end %}
      end

      def self.hide(handle : Void*)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_hide
        {% elsif flag?(:darwin) %}
          LibNativeWindow.lune_hide_window(handle)
        {% end %}
      end

      def self.show(handle : Void*)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_show
        {% elsif flag?(:darwin) %}
          LibNativeWindow.lune_show_window(handle)
        {% end %}
      end

      def self.visible?(handle : Void*) : Bool
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.last_visible
        {% elsif flag?(:darwin) %}
          LibNativeWindow.lune_is_window_visible(handle) != 0
        {% else %}
          true
        {% end %}
      end

      def self.auto_hide_on_resign_key(handle : Void*)
        {% if flag?(:lune_native_test_mock) %}
          # no-op in tests
        {% elsif flag?(:darwin) %}
          LibNativeWindow.lune_window_auto_hide_on_resign_key(handle)
        {% end %}
      end

      # Registers a one-shot callback that fires on the main thread when the
      # NSWindow receives NSWindowWillCloseNotification (OS × button OR programmatic
      # close). The block is always called exactly once and then discarded.
      def self.on_close(handle : Void*, &block : ->) : Nil
        captured = block
        {% if !flag?(:lune_native_test_mock) && flag?(:darwin) %}
          @@close_procs[handle] = captured
          LibNativeWindow.lune_window_observe_close(handle, ->(arg : Void*) {
            if cb = @@close_procs[arg]?
              @@close_procs.delete(arg)
              cb.call
            end
          }, handle)
        {% end %}
      end
    end
  end
end
