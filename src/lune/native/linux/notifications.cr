{% if flag?(:linux) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/linux' && gcc -c notifications.c -o notifications.o `pkg-config --cflags libnotify` 2>/dev/null") %}

  module Lune
    module Native
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/linux/notifications.o `pkg-config --libs libnotify`")]
      lib LibNativeNotifications
        fun show_notification(title : LibC::Char*, body : LibC::Char*) : Void
      end
    end
  end
{% end %}
