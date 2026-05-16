module Lune
  module Native
    {% if flag?(:lune_native_test_mock) %}
      module MenuMock
        @@calls = [] of Symbol
        @@last_app_name : String? = nil

        class_getter calls, last_app_name

        def self.reset
          @@calls.clear
          @@last_app_name = nil
        end

        def self.record_setup_default(app_name : String)
          @@calls << :setup_default
          @@last_app_name = app_name
        end
      end
    {% elsif flag?(:darwin) %}
      {% system("cd '#{__DIR__}/../../../ext/native/macos' && clang -c menu.m -o menu.o -fobjc-arc 2>/dev/null") %}

      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../ext/native/macos/menu.o")]
      lib LibNativeMenu
        fun setup_default_menu(app_name : LibC::Char*) : Void
      end
    {% end %}

    module Menu
      def self.setup_default(app_name : String)
        {% if flag?(:lune_native_test_mock) %}
          MenuMock.record_setup_default(app_name)
        {% elsif flag?(:darwin) %}
          LibNativeMenu.setup_default_menu(app_name)
        {% end %}
      end
    end
  end
end
