module Lune
  module Native
    # Public surface assembled in sibling files:
    #   - mock/notifications.cr    NotificationsMock + Notifications.show delegate
    #   - darwin/notifications.cr  UserNotifications via .m shim
    #   - linux/notifications.cr   libnotify via .c shim
    #   - win32/notifications.cr   PowerShell + WinRT toast shellout
  end
end
