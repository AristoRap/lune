module Lune
  module Native
    {% if flag?(:lune_native_test_mock) %}
      module DeepLinkMock
        @@handler : (String -> Nil)? = nil

        def self.reset
          @@handler = nil
        end

        def self.set_handler(handler : String -> Nil)
          @@handler = handler
        end

        def self.simulate(url : String)
          @@handler.try(&.call(url))
        end
      end
    {% elsif flag?(:darwin) %}
      {% system("cd '#{__DIR__}/../../../ext/native/macos' && clang -c deep_link.m -o deep_link.o -fobjc-arc 2>/dev/null") %}

      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../ext/native/macos/deep_link.o")]
      lib LibNativeDeepLink
        fun lune_deep_link_install(
          cb  : (LibC::Char*, Void*) ->,
          ctx : Void*
        ) : Void
      end
    {% end %}

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
