module Lune
  module Native
    {% if flag?(:lune_native_test_mock) %}
      module NotificationsMock
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
      {% system("cd '#{__DIR__}/../../../ext/native/macos' && clang -c notifications.m -o notifications.o -fobjc-arc 2>/dev/null") %}

      @[Link(framework: "AppKit")]
      @[Link(framework: "UserNotifications")]
      @[Link(framework: "Security")]
      @[Link(ldflags: "#{__DIR__}/../../../ext/native/macos/notifications.o")]
      lib LibNativeNotifications
        fun show_notification(title : LibC::Char*, body : LibC::Char*) : Void
      end
    {% elsif flag?(:linux) %}
      {% system("cd '#{__DIR__}/../../../ext/native/linux' && gcc -c notifications.c -o notifications.o `pkg-config --cflags libnotify` 2>/dev/null") %}

      @[Link(ldflags: "#{__DIR__}/../../../ext/native/linux/notifications.o `pkg-config --libs libnotify`")]
      lib LibNativeNotifications
        fun show_notification(title : LibC::Char*, body : LibC::Char*) : Void
      end
    {% end %}

    module Notifications
      def self.show(title : String, body : String)
        {% if flag?(:lune_native_test_mock) %}
          NotificationsMock.record_show(title, body)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          LibNativeNotifications.show_notification(title, body)
        {% elsif flag?(:win32) %}
          # Shell out to PowerShell + WinRT toast. Title/body travel via
          # env vars so we don't have to escape them into the command line;
          # PowerShell's SecurityElement.Escape handles XML escaping inside
          # the script. The AUMID ("Lune") is unregistered, which means
          # toasts may not persist in the Action Center on first run — but
          # the transient banner still shows.
          script = <<-PS
            [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null
            $t = [System.Security.SecurityElement]::Escape($env:LUNE_TOAST_TITLE)
            $b = [System.Security.SecurityElement]::Escape($env:LUNE_TOAST_BODY)
            $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
            $xml.LoadXml("<toast><visual><binding template='ToastGeneric'><text>$t</text><text>$b</text></binding></visual></toast>")
            $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
            [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Lune").Show($toast)
          PS
          env = {
            "LUNE_TOAST_TITLE" => title,
            "LUNE_TOAST_BODY"  => body,
          }
          Process.run("powershell",
            ["-NoProfile", "-WindowStyle", "Hidden", "-Command", script],
            env: env,
            input: Process::Redirect::Close,
            output: Process::Redirect::Close,
            error: Process::Redirect::Close)
          nil
        {% end %}
      end
    end
  end
end
