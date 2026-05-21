{% if flag?(:linux) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/linux' && gcc -c screen.c -o screen.o `pkg-config --cflags gtk+-3.0` 2>/dev/null") %}

  module Lune
    module Native
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/linux/screen.o")]
      @[Link(ldflags: "`pkg-config --libs gtk+-3.0`")]
      lib LibNativeScreen
        fun screen_info(width : LibC::Int*, height : LibC::Int*, scale : LibC::Double*) : Void
      end
    end
  end
{% end %}
