{% if flag?(:linux) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/linux' && gcc -c dialogs.c -o dialogs.o `pkg-config --cflags gtk+-3.0` 2>/dev/null") %}

  module Lune
    module Native
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/linux/dialogs.o")]
      @[Link(ldflags: "`pkg-config --libs gtk+-3.0`")]
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
