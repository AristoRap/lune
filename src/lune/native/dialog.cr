module Lune
  module Native
    {% if flag?(:lune_native_test_mock) %}
      module DialogMock
        record Call, method : Symbol, title : String, default_name : String = ""

        @@calls = [] of Call
        @@next_open_result : String? = nil
        @@next_save_result : String? = nil

        class_getter calls

        def self.reset
          @@calls.clear
          @@next_open_result = nil
          @@next_save_result = nil
        end

        def self.stub_open(path : String?); @@next_open_result = path; end
        def self.stub_save(path : String?); @@next_save_result = path; end

        def self.record_open(title : String) : String?
          @@calls << Call.new(:open_file, title)
          @@next_open_result
        end

        def self.record_save(title : String, default_name : String) : String?
          @@calls << Call.new(:save_file, title, default_name)
          @@next_save_result
        end
      end
    {% elsif flag?(:darwin) %}
      {% system("cd '#{__DIR__}/../../../ext/native/macos' && clang -c dialog.m -o dialog.o -fobjc-arc 2>/dev/null") %}

      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../ext/native/macos/dialog.o")]
      lib LibNativeDialog
        fun open_file_dialog(title : LibC::Char*, out : LibC::Char*, out_size : LibC::Int) : LibC::Int
        fun save_file_dialog(title : LibC::Char*, default_name : LibC::Char*, out : LibC::Char*, out_size : LibC::Int) : LibC::Int
      end
    {% elsif flag?(:linux) %}
      {% system("cd '#{__DIR__}/../../../ext/native/linux' && gcc -c dialog.c -o dialog.o `pkg-config --cflags gtk+-3.0` 2>/dev/null") %}

      @[Link(ldflags: "#{__DIR__}/../../../ext/native/linux/dialog.o")]
      @[Link(ldflags: "`pkg-config --libs gtk+-3.0`")]
      lib LibNativeDialog
        fun open_file_dialog(title : LibC::Char*, out : LibC::Char*, out_size : LibC::Int) : LibC::Int
        fun save_file_dialog(title : LibC::Char*, default_name : LibC::Char*, out : LibC::Char*, out_size : LibC::Int) : LibC::Int
      end
    {% end %}

    module Dialog
      PATH_BUF_SIZE = 4096

      def self.open_file(title : String) : String?
        {% if flag?(:lune_native_test_mock) %}
          DialogMock.record_open(title)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          buf = Bytes.new(PATH_BUF_SIZE)
          if LibNativeDialog.open_file_dialog(title, buf.to_unsafe.as(LibC::Char*), PATH_BUF_SIZE) == 1
            String.new(buf.to_unsafe)
          end
        {% end %}
      end

      def self.save_file(title : String, default_name : String = "") : String?
        {% if flag?(:lune_native_test_mock) %}
          DialogMock.record_save(title, default_name)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          buf = Bytes.new(PATH_BUF_SIZE)
          if LibNativeDialog.save_file_dialog(title, default_name, buf.to_unsafe.as(LibC::Char*), PATH_BUF_SIZE) == 1
            String.new(buf.to_unsafe)
          end
        {% end %}
      end
    end
  end
end
