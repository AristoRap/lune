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
    end
  end
{% end %}
