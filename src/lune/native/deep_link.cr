module Lune
  module Native
    # Public surface assembled in sibling files:
    #   - mock/deep_link.cr     DeepLinkMock + Lune::Native::DeepLink delegate
    #   - darwin/deep_link.cr   LibNativeDeepLink (NSAppleEventManager via .m) + install
    # Linux and Win32 don't go through Native::DeepLink — the capability
    # uses ARGV scanning + Lune::DeepLinkIPC (Linux only) directly.
  end
end
