module Lune
  module Native
    record ScreenInfo, width : Int32, height : Int32, scale : Float64

    {% if flag?(:lune_native_test_mock) %}
      module ScreenMock
        @@calls       = [] of Symbol
        @@stub_width  = 1920
        @@stub_height = 1080
        @@stub_scale  = 1.0

        class_getter calls

        def self.reset
          @@calls.clear
          @@stub_width  = 1920
          @@stub_height = 1080
          @@stub_scale  = 1.0
        end

        def self.stub_info(width : Int32, height : Int32, scale : Float64)
          @@stub_width  = width
          @@stub_height = height
          @@stub_scale  = scale
        end

        def self.record_info : ScreenInfo
          @@calls << :info
          ScreenInfo.new(@@stub_width, @@stub_height, @@stub_scale)
        end
      end
    {% elsif flag?(:darwin) %}
      {% system("cd '#{__DIR__}/../../../ext/native/macos' && clang -c screen.m -o screen.o -fobjc-arc 2>/dev/null") %}

      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../ext/native/macos/screen.o")]
      lib LibNativeScreen
        fun screen_info(width : LibC::Int*, height : LibC::Int*, scale : LibC::Double*) : Void
      end
    {% elsif flag?(:linux) %}
      {% system("cd '#{__DIR__}/../../../ext/native/linux' && gcc -c screen.c -o screen.o `pkg-config --cflags gtk+-3.0` 2>/dev/null") %}

      @[Link(ldflags: "#{__DIR__}/../../../ext/native/linux/screen.o")]
      @[Link(ldflags: "`pkg-config --libs gtk+-3.0`")]
      lib LibNativeScreen
        fun screen_info(width : LibC::Int*, height : LibC::Int*, scale : LibC::Double*) : Void
      end
    {% elsif flag?(:win32) %}
      @[Link("user32")]
      lib LibUser32Screen
        SM_CXSCREEN = 0
        SM_CYSCREEN = 1
        fun get_system_metrics = GetSystemMetrics(index : LibC::Int) : LibC::Int
        # GetDpiForSystem ships in user32.dll on Windows 10+ (1607). For older
        # Windows the symbol won't resolve; we fall back to GetDeviceCaps.
        fun get_dpi_for_system = GetDpiForSystem : LibC::UInt
      end
    {% end %}

    module Screen
      def self.info : ScreenInfo
        {% if flag?(:lune_native_test_mock) %}
          ScreenMock.record_info
        {% elsif flag?(:darwin) || flag?(:linux) %}
          w = uninitialized LibC::Int
          h = uninitialized LibC::Int
          s = uninitialized LibC::Double
          LibNativeScreen.screen_info(pointerof(w), pointerof(h), pointerof(s))
          ScreenInfo.new(w.to_i32, h.to_i32, s.to_f64)
        {% elsif flag?(:win32) %}
          w = LibUser32Screen.get_system_metrics(LibUser32Screen::SM_CXSCREEN).to_i32
          h = LibUser32Screen.get_system_metrics(LibUser32Screen::SM_CYSCREEN).to_i32
          dpi = LibUser32Screen.get_dpi_for_system
          scale = dpi > 0 ? dpi.to_f64 / 96.0 : 1.0
          ScreenInfo.new(w, h, scale)
        {% else %}
          ScreenInfo.new(0, 0, 1.0)
        {% end %}
      end
    end
  end
end
