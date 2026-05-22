{% if flag?(:win32) && !flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      @[Link("user32")]
      lib LibUser32Screen
        SM_CXSCREEN = 0
        SM_CYSCREEN = 1
        fun get_system_metrics = GetSystemMetrics(index : LibC::Int) : LibC::Int
        # GetDpiForSystem ships in user32.dll on Windows 10+ (1607). For older
        # Windows the symbol won't resolve; we fall back to GetDeviceCaps.
        fun get_dpi_for_system = GetDpiForSystem : LibC::UInt
      end

      module Screen
        def self.info : NamedTuple(width: Int32, height: Int32, scale: Float64)
          w = LibUser32Screen.get_system_metrics(LibUser32Screen::SM_CXSCREEN).to_i32
          h = LibUser32Screen.get_system_metrics(LibUser32Screen::SM_CYSCREEN).to_i32
          dpi = LibUser32Screen.get_dpi_for_system
          scale = dpi > 0 ? dpi.to_f64 / 96.0 : 1.0
          {width: w, height: h, scale: scale}
        end
      end
    end
  end
{% end %}
