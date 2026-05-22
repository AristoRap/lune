{% if flag?(:linux) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/linux' && gcc -c screen.c -o screen.o `pkg-config --cflags gtk+-3.0` 2>/dev/null") %}

  module Lune
    module Native
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/linux/screen.o")]
      @[Link(ldflags: "`pkg-config --libs gtk+-3.0`")]
      lib LibNativeScreen
        fun screen_info(width : LibC::Int*, height : LibC::Int*, scale : LibC::Double*) : Void
      end

      module Screen
        def self.info : NamedTuple(width: Int32, height: Int32, scale: Float64)
          w = uninitialized LibC::Int
          h = uninitialized LibC::Int
          s = uninitialized LibC::Double
          LibNativeScreen.screen_info(pointerof(w), pointerof(h), pointerof(s))
          {width: w.to_i32, height: h.to_i32, scale: s.to_f64}
        end
      end
    end
  end
{% end %}
