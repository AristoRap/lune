module Lune
  module Native
    record ScreenInfo, width : Int32, height : Int32, scale : Float64

    # Public surface assembled in sibling files so each `lib` block + ext
    # compile invocation is isolated to the OS it targets:
    #   - mock/screen.cr    ScreenMock + Screen.info delegate
    #   - darwin/screen.cr  NSScreen via .m shim in ext/native/macos
    #   - linux/screen.cr   Gdk via .c shim in ext/native/linux
    #   - win32/screen.cr   GetSystemMetrics + GetDpiForSystem on user32
  end
end
