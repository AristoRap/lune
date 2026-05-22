{% if flag?(:darwin) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/macos' && clang -c screen.m -o screen.o -fobjc-arc 2>/dev/null") %}

  module Lune
    module Native
      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/macos/screen.o")]
      lib LibNativeScreen
        fun screen_info(width : LibC::Int*, height : LibC::Int*, scale : LibC::Double*) : Void
      end

      module Screen
        def self.info : ScreenInfo
          w = uninitialized LibC::Int
          h = uninitialized LibC::Int
          s = uninitialized LibC::Double
          LibNativeScreen.screen_info(pointerof(w), pointerof(h), pointerof(s))
          ScreenInfo.new(w.to_i32, h.to_i32, s.to_f64)
        end
      end
    end
  end
{% end %}
