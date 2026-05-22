module Lune
  module Native
    # Public surface assembled in sibling files:
    #   - mock/dialogs.cr     DialogsMock + Dialogs delegates (test mode)
    #   - darwin/dialogs.cr   LibNativeDialogs (NSOpenPanel / NSSavePanel) + impl
    #   - linux/dialogs.cr    LibNativeDialogs (GtkFileChooser) + impl
    #   - win32/dialogs.cr    LibComDlg32 + LibShell32Dialog + LibUser32Dialog + impl
    module Dialogs
      PATH_BUF_SIZE  =  4096
      PATHS_BUF_SIZE = 65536
    end
  end
end
