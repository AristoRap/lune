require "base64"

module Lune
  module Native
    # Public surface is assembled across per-OS files in sibling subdirs:
    #   - mock/clipboard.cr     ClipboardMock + Clipboard delegates (test mode)
    #   - darwin/clipboard.cr   LibNativeClipboard + html/image impls (plaintext raises)
    #   - linux/clipboard.cr    xclip shellouts for html/image       (plaintext raises)
    #   - win32/clipboard.cr    LibUser32Clip + LibKernel32Clip + full impl
    # Plaintext read/write is only implemented on Win32 + mock; the capability
    # layer on macOS / Linux uses pbcopy/pbpaste / xclip through Process.run.
    module Clipboard
      HTML_BUF_SIZE  = 1 * 1024 * 1024  # 1 MB — generous for any HTML payload
      IMAGE_BUF_SIZE = 10 * 1024 * 1024 # 10 MB — covers base64 of most clipboard images
    end
  end
end
