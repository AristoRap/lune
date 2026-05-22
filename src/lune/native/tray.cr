module Lune
  module Native
    # Public surface assembled in sibling files:
    #   - mock/tray.cr     TrayMock + Tray delegates (test mode)
    #   - darwin/tray.cr   LibNativeTray (.m shim — NSStatusItem) + impl
    #   - linux/tray.cr    LibNativeTray (GtkStatusIcon via .c shim) + impl
    #                      (button_screen_rect / set_right_click_cb / popup_menu no-op)
    #   - win32/tray.cr    LibUser32Tray + LibKernel32Tray + LibShell32Tray + full impl
    #                      (message-only HWND, Shell_NotifyIcon, op queue, pump fiber)
    #
    # `has_menu?` reflects the most recent `set_menu` call across all platforms;
    # the flag itself lives here so per-OS files just flip it.
    module Tray
      @@has_menu : Bool = false

      def self.has_menu? : Bool
        @@has_menu
      end
    end
  end
end
