{% if flag?(:darwin) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/macos' && clang -c tray.m -o tray.o -fobjc-arc 2>/dev/null") %}

  module Lune
    module Native
      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/macos/tray.o")]
      lib LibNativeTray
        alias Callback     = (Void*) -> Void
        alias MenuCallback = (LibC::Char*, Void*) -> Void
        fun tray_show(icon_path : LibC::Char*, callback : Callback, userdata : Void*) : Void
        fun tray_hide : Void
        fun tray_set_icon(icon_path : LibC::Char*) : Void
        fun tray_set_menu(ids : LibC::Char**, labels : LibC::Char**, count : LibC::Int, callback : MenuCallback, userdata : Void*) : Void
        struct TrayRect
          x : LibC::Int
          y : LibC::Int
          width : LibC::Int
          height : LibC::Int
        end
        fun lune_tray_button_screen_rect : TrayRect
        fun lune_tray_set_right_click_cb(callback : Callback, userdata : Void*) : Void
        fun tray_popup_menu : Void
      end
    end
  end
{% end %}
