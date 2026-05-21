{% if flag?(:darwin) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/macos' && clang -c menu.m -o menu.o -fobjc-arc 2>/dev/null") %}

  module Lune
    module Native
      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/macos/menu.o")]
      lib LibNativeMenu
        fun setup_default_menu(app_name : LibC::Char*) : Void
        fun lune_set_menu(
          app_name : LibC::Char*,
          json     : LibC::Char*,
          cb       : (LibC::Char*, Void*) ->,
          ctx      : Void*
        ) : Void
        fun lune_show_context_menu(
          window : Void*,
          x      : LibC::Float,
          y      : LibC::Float,
          json   : LibC::Char*,
          cb     : (LibC::Char*, Void*) ->,
          ctx    : Void*
        ) : Void
      end
    end
  end
{% end %}
