{% if flag?(:darwin) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/darwin' && clang -c notifications.m -o notifications.o -fobjc-arc 2>/dev/null") %}

  module Lune
    module Native
      @[Link(framework: "AppKit")]
      @[Link(framework: "UserNotifications")]
      @[Link(framework: "Security")]
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/darwin/notifications.o")]
      lib LibNativeNotifications
        fun show_notification(title : LibC::Char*, body : LibC::Char*) : Void
      end

      module Notifications
        def self.show(title : String, body : String)
          LibNativeNotifications.show_notification(title, body)
        end
      end
    end
  end
{% end %}
