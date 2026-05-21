module Lune
  module Native
    record ScreenInfo, width : Int32, height : Int32, scale : Float64

    # Platform implementations live in sibling files so each `lib` block + ext
    # compile invocation is isolated to the OS it targets:
    #   - screen_mock.cr   (under -Dlune_native_test_mock)
    #   - screen_darwin.cr (NSScreen via .m shim in ext/native/macos)
    #   - screen_linux.cr  (Gdk via .c shim in ext/native/linux)
    #   - screen_win32.cr  (GetSystemMetrics + GetDpiForSystem on user32)
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
