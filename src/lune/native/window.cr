module Lune
  module Native
    {% if flag?(:lune_native_test_mock) %}
      module WindowMock
        @@calls = [] of Symbol
        @@last_title : String? = nil
        @@last_size : Tuple(Int32, Int32)? = nil

        class_getter calls, last_title, last_size

        def self.reset
          @@calls.clear
          @@last_title = nil
          @@last_size = nil
        end

        def self.record_minimize;              @@calls << :minimize; end
        def self.record_maximize;              @@calls << :maximize; end
        def self.record_center;                @@calls << :center; end
        def self.record_set_title(t : String); @@calls << :set_title; @@last_title = t; end
        def self.record_set_size(w : Int32, h : Int32)
          @@calls << :set_size
          @@last_size = {w, h}
        end
      end
    {% elsif flag?(:darwin) %}
      {% system("cd '#{__DIR__}/../../../ext/native/macos' && clang -c window.m -o window.o -fobjc-arc 2>/dev/null") %}

      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../ext/native/macos/window.o")]
      lib LibNativeWindow
        fun minimize(window : Void*) : Void
        fun maximize(window : Void*) : Void
        fun set_title(window : Void*, title : LibC::Char*) : Void
        fun set_size(window : Void*, width : LibC::Int, height : LibC::Int) : Void
        fun center(window : Void*) : Void
      end
    {% elsif flag?(:linux) %}
      {% system("cd '#{__DIR__}/../../../ext/native/linux' && gcc -c window.c -o window.o `pkg-config --cflags gtk+-3.0` 2>/dev/null") %}

      @[Link(ldflags: "#{__DIR__}/../../../ext/native/linux/window.o")]
      @[Link(ldflags: "`pkg-config --libs gtk+-3.0`")]
      lib LibNativeWindow
        fun minimize(window : Void*) : Void
        fun maximize(window : Void*) : Void
        fun set_title(window : Void*, title : LibC::Char*) : Void
        fun set_size(window : Void*, width : LibC::Int, height : LibC::Int) : Void
        fun center(window : Void*) : Void
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
    end
  end
end
