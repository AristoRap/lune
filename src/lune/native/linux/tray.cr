{% if flag?(:linux) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/linux' && gcc -c tray.c -o tray.o `pkg-config --cflags gtk+-3.0` 2>/dev/null") %}

  module Lune
    module Native
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/linux/tray.o")]
      @[Link(ldflags: "`pkg-config --libs gtk+-3.0`")]
      lib LibNativeTray
        alias Callback     = (Void*) -> Void
        alias MenuCallback = (LibC::Char*, Void*) -> Void
        fun tray_show(icon_path : LibC::Char*, callback : Callback, userdata : Void*) : Void
        fun tray_hide : Void
        fun tray_set_icon(icon_path : LibC::Char*) : Void
        fun tray_set_menu(ids : LibC::Char**, labels : LibC::Char**, count : LibC::Int, callback : MenuCallback, userdata : Void*) : Void
      end
    end
  end
{% end %}
