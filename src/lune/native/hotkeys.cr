module Lune
  module Native
    # Public surface assembled in sibling files:
    #   - mock/hotkeys.cr     HotkeysMock + Hotkeys delegates (test mode)
    #   - darwin/hotkeys.cr   LibNativeHotkeys (.m shim + Carbon) + Hotkeys impl
    #   - linux/hotkeys.cr    LibX11Hotkeys + Hotkeys impl (XGrabKey + pump fiber)
    #   - win32/hotkeys.cr    LibUser32Hotkeys + Hotkeys impl (RegisterHotKey + pump thread)
  end
end
