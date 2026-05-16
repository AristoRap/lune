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
        end

        def self.mock_frame=(f : Tuple(Int32, Int32, Int32, Int32))
          @@mock_frame = f
        end

        def self.record_minimize;              @@calls << :minimize; end
        def self.record_maximize;              @@calls << :maximize; end
        def self.record_center;                @@calls << :center; end
        def self.record_set_title(t : String); @@calls << :set_title; @@last_title = t; end
        def self.record_set_size(w : Int32, h : Int32)
          @@calls << :set_size
          @@last_size = {w, h}
        end
        def self.record_set_frame(x : Int32, y : Int32, w : Int32, h : Int32)
          @@calls << :set_frame
          @@last_frame = {x, y, w, h}
        end
        @@last_appearance : Int32? = nil
        @@last_drop_cb : (Array(String) -> Nil)? = nil
        class_getter last_appearance, last_drop_cb

        def self.record_setup_file_drop(cb : Array(String) -> Nil)
          @@calls << :setup_file_drop
          @@last_drop_cb = cb
        end

        def self.simulate_drop(paths : Array(String))
          @@last_drop_cb.try(&.call(paths))
        end

        def self.record_set_titlebar_transparent(full_size_content : Bool)
          @@calls << :set_titlebar_transparent
          @@last_full_size_content = full_size_content
        end
        def self.record_set_background_transparent; @@calls << :set_background_transparent; end
        def self.record_setup_drag_monitor;         @@calls << :setup_drag_monitor; end
        def self.record_start_window_drag;          @@calls << :start_window_drag; end
        def self.record_hide_title;                 @@calls << :hide_title; end
        def self.record_set_appearance(mode : Int32)
          @@calls << :set_appearance
          @@last_appearance = mode
        end
        def self.record_set_content_protection; @@calls << :set_content_protection; end
        def self.record_set_always_on_top;      @@calls << :set_always_on_top; end
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
        fun setup_file_drop(window : Void*, callback : DropCallback, userdata : Void*) : Void
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
        alias DropCallback = (LibC::Char*, Void*) -> Void
        fun setup_file_drop(window : Void*, callback : DropCallback, userdata : Void*) : Void
      end
    {% end %}

    module Window
      # Kept at class level so GC never collects the boxed callback while the window is open.
      @@drop_box : Pointer(Void) = Pointer(Void).null

      def self.setup_file_drop(handle : Void*, on_drop : Array(String) -> Nil)
        {% if flag?(:lune_native_test_mock) %}
          WindowMock.record_setup_file_drop(on_drop)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          @@drop_box = Box.box(on_drop)
          LibNativeWindow.setup_file_drop(handle, ->(json_ptr : LibC::Char*, data : Void*) {
            return if data.null?
            paths = Array(String).from_json(String.new(json_ptr))
            Box(Proc(Array(String), Nil)).unbox(data).call(paths)
          }, @@drop_box)
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
