module Lune
  module Native
    # Platform implementations live in sibling files:
    #   - deep_link_mock.cr   (under -Dlune_native_test_mock)
    #   - deep_link_darwin.cr (NSAppleEventManager via .m shim)
    # Linux/Win32 currently no-op (Linux: docs claim support but runtime
    # handler not yet implemented; Win32: raises NotImplementedError).
    module DeepLink
      @@box : Void*? = nil

      def self.install(&handler : String -> Nil)
        cb = handler
        {% if flag?(:lune_native_test_mock) %}
          DeepLinkMock.set_handler(cb)
        {% elsif flag?(:darwin) %}
          @@box = Box.box(cb)
          LibNativeDeepLink.lune_deep_link_install(
            ->(url : LibC::Char*, ctx : Void*) {
              fn = Box(Proc(String, Nil)).unbox(ctx)
              fn.call(String.new(url))
            },
            @@box.not_nil!
          )
        {% elsif flag?(:win32) %}
          raise NotImplementedError.new("Lune::Native::DeepLink.install is not implemented on Windows yet (v0.10.0 backlog)")
        {% end %}
        # NOTE: Linux currently has no runtime URL-scheme handler either — the
        # capability silently no-ops there despite the docs claiming Linux
        # support. Tracked separately from the Windows port.
      end
    end
  end
end
