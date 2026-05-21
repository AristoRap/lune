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
          # the script.
          #
          # AUMID registration via HKCU\Software\Classes\AppUserModelId is the
          # Microsoft-documented path for non-UWP desktop apps to receive
          # toasts (see learn.microsoft.com → "Send a local toast notification
          # from other types of unpackaged apps"). The key only needs to exist
          # once per user; we Test-Path and skip the write on subsequent calls.
          # Without this, Windows silently drops the toast even when the WinRT
          # call returns success.
          #
          # Two separate WinRT projections need explicit loading: loading the
          # Windows.UI.Notifications type alone doesn't make Windows.Data.Xml.Dom
          # available, and New-Object on XmlDocument fails with TypeNotFound.
          script = <<-PS
            $aumid = "Lune"
            $aumidKey = "HKCU:\\SOFTWARE\\Classes\\AppUserModelId\\$aumid"
            if (-not (Test-Path $aumidKey)) {
                New-Item -Path $aumidKey -Force | Out-Null
                Set-ItemProperty -Path $aumidKey -Name "DisplayName" -Value $aumid -Type String
            }

            [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null
            [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType=WindowsRuntime] | Out-Null
            $t = [System.Security.SecurityElement]::Escape($env:LUNE_TOAST_TITLE)
            $b = [System.Security.SecurityElement]::Escape($env:LUNE_TOAST_BODY)
            $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
            $xml.LoadXml("<toast><visual><binding template='ToastGeneric'><text>$t</text><text>$b</text></binding></visual></toast>")
            $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
            [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($aumid).Show($toast)
          PS
          env = {
            "LUNE_TOAST_TITLE" => title,
            "LUNE_TOAST_BODY"  => body,
          }
          stderr_buf = IO::Memory.new
          stdout_buf = IO::Memory.new
          status = Process.run("powershell",
            ["-NoProfile", "-WindowStyle", "Hidden", "-Command", script],
            env: env,
            input: Process::Redirect::Close,
            output: stdout_buf,
            error: stderr_buf)
          unless status.success?
            Lune.logger.warn { "Notifications: powershell exited with code=#{status.exit_code? || -1}" }
            err = stderr_buf.to_s.strip
            out = stdout_buf.to_s.strip
            Lune.logger.warn { "Notifications: powershell stderr: #{err}" } unless err.empty?
            Lune.logger.warn { "Notifications: powershell stdout: #{out}" } unless out.empty?
          else
            # PowerShell can still print warnings on success (e.g. AUMID not
            # registered → CreateToastNotifier may emit a warning to stderr but
            # exit 0). Surface those at debug so we can see them with
            # LUNE_LOG=debug without spamming standard runs.
            Lune.logger.debug do
              err = stderr_buf.to_s.strip
              out = stdout_buf.to_s.strip
              parts = [] of String
              parts << "stderr=#{err}" unless err.empty?
              parts << "stdout=#{out}" unless out.empty?
              parts.empty? ? "Notifications: powershell succeeded (no output)" : "Notifications: powershell succeeded — #{parts.join(", ")}"
            end
          end
          nil
        {% end %}
      end
    end
  end
end
