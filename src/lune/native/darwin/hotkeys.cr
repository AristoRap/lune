{% if flag?(:darwin) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/macos' && clang -c hotkeys.m -o hotkeys.o -fobjc-arc -Wno-deprecated-declarations 2>/dev/null") %}

  module Lune
    module Native
      @[Link(framework: "Carbon")]
      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/macos/hotkeys.o")]
      lib LibNativeHotkeys
        fun lune_hotkeys_init(
          cb  : (LibC::Char*, Void*) ->,
          ctx : Void*
        ) : Void
        fun lune_hotkeys_register(accelerator : LibC::Char*) : LibC::Int
        fun lune_hotkeys_unregister(accelerator : LibC::Char*) : LibC::Int
        fun lune_hotkeys_unregister_all : Void
      end
    end
  end
{% end %}
