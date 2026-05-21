{% if flag?(:darwin) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/macos' && clang -c clipboard.m -o clipboard.o -fobjc-arc 2>/dev/null") %}

  module Lune
    module Native
      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/macos/clipboard.o")]
      lib LibNativeClipboard
        fun clipboard_read_html(out : LibC::Char*, out_size : LibC::Int) : LibC::Int
        fun clipboard_write_html(html : LibC::Char*) : Void
        fun clipboard_read_image(out : LibC::Char*, out_size : LibC::Int) : LibC::Int
        fun clipboard_write_image(data_url : LibC::Char*) : Void
      end
    end
  end
{% end %}
