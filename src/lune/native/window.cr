module Lune
  module Native
    {% if flag?(:lune_native_test_mock) %}
      module WindowMock
        @@calls = [] of Symbol
        @@last_title : String? = nil
        @@last_size : Tuple(Int32, Int32)? = nil
        @@last_frame : Tuple(Int32, Int32, Int32, Int32)? = nil
        @@mock_frame : Tuple(Int32, Int32, Int32, Int32) = {0, 0, 1200, 800}
        @@last_full_size_content : Bool? = nil

        class_getter calls, last_title, last_size, last_frame, mock_frame, last_full_size_content

        def self.reset
          @@calls.clear
          @@last_title = nil
          @@last_size = nil
          @@last_frame = nil
          @@mock_frame = {0, 0, 1200, 800}
          @@last_full_size_content = nil
          @@last_appearance = nil
          @@last_drop_cb = nil
          @@last_drag_out_paths = nil
        end

        def self.mock_frame=(f : Tuple(Int32, Int32, Int32, Int32))
          @@mock_frame = f
        end

        def self.record_minimize
          @@calls << :minimize
        end

        def self.record_maximize
          @@calls << :maximize
        end

        def self.record_center
          @@calls << :center
        end

        def self.record_set_title(t : String)
          @@calls << :set_title; @@last_title = t
        end

        def self.record_set_size(w : Int32, h : Int32)
          @@calls << :set_size
          @@last_size = {w, h}
        end

        def self.record_set_frame(x : Int32, y : Int32, w : Int32, h : Int32)
          @@calls << :set_frame
          @@last_frame = {x, y, w, h}
        end

        @@last_appearance : Int32? = nil
        @@last_drop_cb : ((Int32, Int32, Array(String)) -> Nil)? = nil
        class_getter last_appearance, last_drop_cb

        def self.record_disable_webview_drop
          @@calls << :disable_webview_drop
        end

        def self.record_setup_file_drop(cb : (Int32, Int32, Array(String)) -> Nil)
          @@calls << :setup_file_drop
          @@last_drop_cb = cb
        end

        def self.simulate_drop(x : Int32, y : Int32, paths : Array(String))
          @@last_drop_cb.try(&.call(x, y, paths))
        end

        @@last_drag_out_paths : Array(String)? = nil
        class_getter last_drag_out_paths

        def self.record_start_drag_out(paths : Array(String))
          @@calls << :start_drag_out
          @@last_drag_out_paths = paths
        end

        def self.record_set_titlebar_transparent(full_size_content : Bool)
          @@calls << :set_titlebar_transparent
          @@last_full_size_content = full_size_content
        end

        def self.record_set_background_transparent
          @@calls << :set_background_transparent
        end

        def self.record_setup_drag_monitor
          @@calls << :setup_drag_monitor
        end

        def self.record_start_window_drag
          @@calls << :start_window_drag
        end

        def self.record_hide_title
          @@calls << :hide_title
        end

        def self.record_hide_traffic_lights
          @@calls << :hide_traffic_lights
        end

        def self.record_set_appearance(mode : Int32)
          @@calls << :set_appearance
          @@last_appearance = mode
        end

        def self.record_set_content_protection
          @@calls << :set_content_protection
        end

        def self.record_set_always_on_top
          @@calls << :set_always_on_top
        end

        @@last_visible : Bool = true
        class_getter last_visible

        def self.record_set_activation_policy_accessory
          @@calls << :set_activation_policy_accessory
        end

        def self.record_hide
          @@calls << :hide
          @@last_visible = false
        end

        def self.record_show
          @@calls << :show
          @@last_visible = true
        end

        def self.mock_visible=(v : Bool)
          @@last_visible = v
        end
      end
    {% elsif flag?(:darwin) %}
      {% system("cd '#{__DIR__}/../../../ext/native/macos' && clang -c window.m -o window.o -fobjc-arc 2>/dev/null") %}

      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../ext/native/macos/window.o")]
      lib LibNativeWindow
        struct Frame
          x : LibC::Int
          y : LibC::Int
          width : LibC::Int
          height : LibC::Int
        end
        fun minimize(window : Void*) : Void
        fun maximize(window : Void*) : Void
        fun set_title(window : Void*, title : LibC::Char*) : Void
        fun set_size(window : Void*, width : LibC::Int, height : LibC::Int) : Void
        fun center(window : Void*) : Void
        fun get_frame(window : Void*) : Frame
        fun set_frame(window : Void*, x : LibC::Int, y : LibC::Int, width : LibC::Int, height : LibC::Int) : Void
        fun set_titlebar_transparent(window : Void*, full_size_content : LibC::Int) : Void
        fun set_background_transparent(window : Void*) : Void
        fun setup_drag_monitor : Void
        fun start_window_drag(window : Void*) : Void
        fun hide_title(window : Void*) : Void
        fun hide_traffic_lights(window : Void*) : Void
        fun set_appearance(window : Void*, mode : LibC::Int) : Void
        fun set_content_protection(window : Void*, enabled : LibC::Int) : Void
        fun set_always_on_top(window : Void*, enabled : LibC::Int) : Void
        alias DropCallback = (LibC::Char*, Void*) -> Void
        fun disable_webview_drop(window : Void*) : Void
        # drag_pos_fn: JS function name, e.g. "window.__lune.dragPos", or NULL
        fun setup_file_drop(window : Void*,
                            drop_cb : DropCallback, drop_ud : Void*,
                            drag_pos_fn : LibC::Char*) : Void
        fun lune_start_drag_out(window : Void*, paths_json : LibC::Char*) : Void
        fun lune_window_close(window : Void*) : Void
        alias CloseCallback = Void* ->
        fun lune_window_observe_close(window : Void*, cb : CloseCallback, arg : Void*) : Void
        fun lune_set_activation_policy_accessory : Void
        fun lune_hide_window(window : Void*) : Void
        fun lune_show_window(window : Void*) : Void
        fun lune_is_window_visible(window : Void*) : LibC::Int
        fun lune_window_auto_hide_on_resign_key(window : Void*) : Void
      end
    {% elsif flag?(:linux) %}
      {% system("cd '#{__DIR__}/../../../ext/native/linux' && gcc -c window.c -o window.o `pkg-config --cflags gtk+-3.0` 2>/dev/null") %}

      @[Link(ldflags: "#{__DIR__}/../../../ext/native/linux/window.o")]
      @[Link(ldflags: "`pkg-config --libs gtk+-3.0`")]
      lib LibNativeWindow
        struct Frame
          x : LibC::Int
          y : LibC::Int
          width : LibC::Int
          height : LibC::Int
        end
        fun minimize(window : Void*) : Void
        fun maximize(window : Void*) : Void
        fun set_title(window : Void*, title : LibC::Char*) : Void
        fun set_size(window : Void*, width : LibC::Int, height : LibC::Int) : Void
        fun center(window : Void*) : Void
        fun get_frame(window : Void*) : Frame
        fun set_frame(window : Void*, x : LibC::Int, y : LibC::Int, width : LibC::Int, height : LibC::Int) : Void
        alias DropCallback    = (LibC::Char*, Void*) -> Void
        alias DragPosCallback = (LibC::Int, LibC::Int, Void*) -> Void
        fun disable_webview_drop(window : Void*) : Void
        fun setup_file_drop(window : Void*,
                            drop_cb : DropCallback, drop_ud : Void*,
                            pos_cb : DragPosCallback, pos_ud : Void*) : Void
      end
    {% elsif flag?(:win32) %}
      # Win32 window basics use user32.dll directly — no .o shim needed. The
      # `handle : Void*` arg is the HWND returned by the webview shard via
      # `wv.native_handle(Webview::NativeHandleKind::UI_WINDOW)`.
      @[Link("user32")]
      lib LibUser32
        struct Rect
          left   : LibC::Long
          top    : LibC::Long
          right  : LibC::Long
          bottom : LibC::Long
        end

        SW_HIDE      =  0
        SW_SHOWNORMAL =  1
        SW_MAXIMIZE  =  3
        SW_MINIMIZE  =  6
        SW_RESTORE   =  9

        SWP_NOSIZE   = 0x0001_u32
        SWP_NOZORDER = 0x0004_u32

        SM_CXSCREEN  = 0
        SM_CYSCREEN  = 1

        fun get_window_rect = GetWindowRect(hwnd : Void*, rect : Rect*) : LibC::Int
        fun move_window = MoveWindow(hwnd : Void*, x : LibC::Int, y : LibC::Int, w : LibC::Int, h : LibC::Int, repaint : LibC::Int) : LibC::Int
        fun set_window_text_w = SetWindowTextW(hwnd : Void*, text : UInt16*) : LibC::Int
        fun show_window = ShowWindow(hwnd : Void*, cmd : LibC::Int) : LibC::Int
        fun set_window_pos = SetWindowPos(hwnd : Void*, after : Void*, x : LibC::Int, y : LibC::Int, w : LibC::Int, h : LibC::Int, flags : UInt32) : LibC::Int
        fun get_system_metrics = GetSystemMetrics(index : LibC::Int) : LibC::Int
      end
    {% end %}

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

      # on_drop     receives (x, y, paths) — coordinates in CSS pixels (origin top-left)
      # on_pos      receives (x, y) on each drag-move (Linux only; macOS uses drag_pos_fn)
      # drag_pos_fn JS function name called natively on macOS, e.g. "window.__lune.dragPos"
      def self.setup_file_drop(handle : Void*,
                               on_drop : (Int32, Int32, Array(String)) -> Nil,
                               on_pos : (Int32, Int32) -> Nil,
                               drag_pos_fn : String? = nil)
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
            drag_pos_fn ? drag_pos_fn.to_unsafe : Pointer(LibC::Char).null
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
