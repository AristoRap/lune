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
    {% end %}

    module Window
      # Kept at class level so GC never collects boxed callbacks while the window is live.
      @@drop_box : Pointer(Void) = Pointer(Void).null
      @@drop_pos_box : Pointer(Void) = Pointer(Void).null

      def self.disable_webview_drop(handle : Void*)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_disable_webview_drop
        {% elsif flag?(:darwin) || flag?(:linux) %}
          LibNativeWindow.disable_webview_drop(handle)
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
          @@drop_box = Box.box(on_drop)
          # on_pos is unused on macOS — the ObjC overlay calls evaluateJavaScript:
          # directly via drag_pos_fn, eliminating the double-async dispatch chain.
          LibNativeWindow.setup_file_drop(
            handle,
            ->(json_ptr : LibC::Char*, data : Void*) {
              return if data.null?
              parsed = JSON.parse(String.new(json_ptr))
              x = parsed["x"]?.try(&.as_i?) || 0
              y = parsed["y"]?.try(&.as_i?) || 0
              paths = parsed["paths"]?.try(&.as_a?)&.compact_map(&.as_s?) || [] of String
              Box(Proc(Int32, Int32, Array(String), Nil)).unbox(data).call(x, y, paths)
            },
            @@drop_box,
            drag_pos_fn ? drag_pos_fn.to_unsafe : Pointer(LibC::Char).null
          )
        {% elsif flag?(:linux) %}
          @@drop_box = Box.box(on_drop)
          @@drop_pos_box = Box.box(on_pos)
          LibNativeWindow.setup_file_drop(
            handle,
            ->(json_ptr : LibC::Char*, data : Void*) {
              return if data.null?
              parsed = JSON.parse(String.new(json_ptr))
              x = parsed["x"]?.try(&.as_i?) || 0
              y = parsed["y"]?.try(&.as_i?) || 0
              paths = parsed["paths"]?.try(&.as_a?)&.compact_map(&.as_s?) || [] of String
              Box(Proc(Int32, Int32, Array(String), Nil)).unbox(data).call(x, y, paths)
            },
            @@drop_box,
            ->(x : LibC::Int, y : LibC::Int, data : Void*) {
              return if data.null?
              Box(Proc(Int32, Int32, Nil)).unbox(data).call(x.to_i32, y.to_i32)
            },
            @@drop_pos_box
          )
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
        {% end %}
      end

      def self.maximize(handle : Void*)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_maximize
        {% elsif flag?(:darwin) || flag?(:linux) %}
          LibNativeWindow.maximize(handle)
        {% end %}
      end

      def self.center(handle : Void*)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_center
        {% elsif flag?(:darwin) || flag?(:linux) %}
          LibNativeWindow.center(handle)
        {% end %}
      end

      def self.set_title(handle : Void*, title : String)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_set_title(title)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          LibNativeWindow.set_title(handle, title)
        {% end %}
      end

      def self.set_size(handle : Void*, width : Int32, height : Int32)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_set_size(width, height)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          LibNativeWindow.set_size(handle, width, height)
        {% end %}
      end

      def self.get_frame(handle : Void*) : {Int32, Int32, Int32, Int32}
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.mock_frame
        {% elsif flag?(:darwin) || flag?(:linux) %}
          f = LibNativeWindow.get_frame(handle)
          {f.x.to_i32, f.y.to_i32, f.width.to_i32, f.height.to_i32}
        {% else %}
          {0, 0, 0, 0}
        {% end %}
      end

      def self.set_frame(handle : Void*, x : Int32, y : Int32, width : Int32, height : Int32)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_set_frame(x, y, width, height)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          LibNativeWindow.set_frame(handle, x, y, width, height)
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
    end
  end
end
