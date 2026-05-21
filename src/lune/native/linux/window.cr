{% if flag?(:linux) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/linux' && gcc -c window.c -o window.o `pkg-config --cflags gtk+-3.0` 2>/dev/null") %}

  module Lune
    module Native
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/linux/window.o")]
      @[Link(ldflags: "`pkg-config --libs gtk+-3.0`")]
      lib LibNativeWindow
        struct Frame
          x : LibC::Int
          y : LibC::Int
          width : LibC::Int
          height : LibC::Int
        end
        fun minimize(window : Void*) : Void
        fun maximize(window : Void*) : Void
        fun set_title(window : Void*, title : LibC::Char*) : Void
        fun set_size(window : Void*, width : LibC::Int, height : LibC::Int) : Void
        fun center(window : Void*) : Void
        fun get_frame(window : Void*) : Frame
        fun set_frame(window : Void*, x : LibC::Int, y : LibC::Int, width : LibC::Int, height : LibC::Int) : Void
        alias DropCallback    = (LibC::Char*, Void*) -> Void
        alias DragPosCallback = (LibC::Int, LibC::Int, Void*) -> Void
        fun disable_webview_drop(window : Void*) : Void
        fun setup_file_drop(window : Void*,
                            drop_cb : DropCallback, drop_ud : Void*,
                            pos_cb : DragPosCallback, pos_ud : Void*) : Void
      end
    end
  end
{% end %}
