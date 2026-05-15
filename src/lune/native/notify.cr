module Lune
  module Native
    {% if flag?(:lune_native_test_mock) %}
      module NotifyMock
        @@calls = [] of Symbol
        @@last_title : String? = nil
        @@last_body : String? = nil

        class_getter calls, last_title, last_body

        def self.reset
          @@calls.clear
          @@last_title = nil
          @@last_body = nil
        end

        def self.record_show(title : String, body : String)
          @@calls << :show
          @@last_title = title
          @@last_body = body
        end
      end
    {% elsif flag?(:darwin) %}
      {% system("cd '#{__DIR__}/../../../ext/native/macos' && clang -c notify.m -o notify.o -fobjc-arc 2>/dev/null") %}

      @[Link(framework: "AppKit")]
      @[Link(framework: "UserNotifications")]
      @[Link(ldflags: "#{__DIR__}/../../../ext/native/macos/notify.o")]
      lib LibNativeNotify
        fun show_notification(title : LibC::Char*, body : LibC::Char*) : Void
      end
    {% elsif flag?(:linux) %}
      {% system("cd '#{__DIR__}/../../../ext/native/linux' && gcc -c notify.c -o notify.o `pkg-config --cflags libnotify` 2>/dev/null") %}

      @[Link(ldflags: "#{__DIR__}/../../../ext/native/linux/notify.o")]
      @[Link(ldflags: "`pkg-config --libs libnotify`")]
      lib LibNativeNotify
        fun show_notification(title : LibC::Char*, body : LibC::Char*) : Void
      end
    {% end %}

    module Notify
      def self.show(title : String, body : String)
        {% if flag?(:lune_native_test_mock) %}
          NotifyMock.record_show(title, body)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          LibNativeNotify.show_notification(title, body)
        {% end %}
      end
    end
  end
end
