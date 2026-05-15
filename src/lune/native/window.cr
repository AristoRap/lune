module Lune
  module Native
    {% if flag?(:lune_native_test_mock) %}
      module WindowMock
        @@calls = [] of Symbol
        @@last_title : String? = nil
        @@last_size : Tuple(Int32, Int32)? = nil
        @@last_frame : Tuple(Int32, Int32, Int32, Int32)? = nil
        @@mock_frame : Tuple(Int32, Int32, Int32, Int32) = {0, 0, 1200, 800}

        class_getter calls, last_title, last_size, last_frame, mock_frame

        def self.reset
          @@calls.clear
          @@last_title = nil
          @@last_size = nil
          @@last_frame = nil
          @@mock_frame = {0, 0, 1200, 800}
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
      end
    {% end %}

    module Window
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
    end
  end
end
