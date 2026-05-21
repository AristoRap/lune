{% if flag?(:darwin) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/macos' && clang -c dialogs.m -o dialogs.o -fobjc-arc 2>/dev/null") %}

  module Lune
    module Native
      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/macos/dialogs.o")]
      lib LibNativeDialogs
        fun open_file_dialog(title : LibC::Char*, out : LibC::Char*, out_size : LibC::Int) : LibC::Int
        fun open_dir_dialog(title : LibC::Char*, out : LibC::Char*, out_size : LibC::Int) : LibC::Int
        fun open_files_dialog(title : LibC::Char*, out : LibC::Char*, out_size : LibC::Int) : LibC::Int
        fun save_file_dialog(title : LibC::Char*, default_name : LibC::Char*, out : LibC::Char*, out_size : LibC::Int) : LibC::Int
        fun message_dialog(type : LibC::Int, title : LibC::Char*, message : LibC::Char*, out : LibC::Char*, out_size : LibC::Int) : LibC::Int
      end
    end
  end
{% end %}
