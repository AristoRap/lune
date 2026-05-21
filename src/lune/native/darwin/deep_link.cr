{% if flag?(:darwin) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/macos' && clang -c deep_link.m -o deep_link.o -fobjc-arc 2>/dev/null") %}

  module Lune
    module Native
      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/macos/deep_link.o")]
      lib LibNativeDeepLink
        fun lune_deep_link_install(
          cb  : (LibC::Char*, Void*) ->,
          ctx : Void*
        ) : Void
      end
    end
  end
{% end %}
