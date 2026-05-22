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

      module Dialogs
        PATH_BUF_SIZE  =  4096
        PATHS_BUF_SIZE = 65536

        def self.open_file(title : String) : String?
          buf = Bytes.new(PATH_BUF_SIZE)
          if LibNativeDialogs.open_file_dialog(title, buf.to_unsafe.as(LibC::Char*), PATH_BUF_SIZE) == 1
            String.new(buf.to_unsafe)
          end
        end

        def self.open_dir(title : String) : String?
          buf = Bytes.new(PATH_BUF_SIZE)
          if LibNativeDialogs.open_dir_dialog(title, buf.to_unsafe.as(LibC::Char*), PATH_BUF_SIZE) == 1
            String.new(buf.to_unsafe)
          end
        end

        def self.open_files(title : String) : Array(String)
          buf = Bytes.new(PATHS_BUF_SIZE)
          if LibNativeDialogs.open_files_dialog(title, buf.to_unsafe.as(LibC::Char*), PATHS_BUF_SIZE) == 1
            String.new(buf.to_unsafe).split('\n').reject(&.empty?)
          else
            [] of String
          end
        end

        def self.save_file(title : String, default_name : String = "") : String?
          buf = Bytes.new(PATH_BUF_SIZE)
          if LibNativeDialogs.save_file_dialog(title, default_name, buf.to_unsafe.as(LibC::Char*), PATH_BUF_SIZE) == 1
            String.new(buf.to_unsafe)
          end
        end

        def self.message(type : Int32, title : String, message : String) : String
          buf = Bytes.new(16)
          LibNativeDialogs.message_dialog(type, title, message, buf.to_unsafe.as(LibC::Char*), 16)
          String.new(buf.to_unsafe)
        end
      end
    end
  end
{% end %}
