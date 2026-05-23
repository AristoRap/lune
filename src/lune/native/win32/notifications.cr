{% if flag?(:win32) && !flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      # Win32 toast notifications via PowerShell + WinRT. No separate lib block —
      # the entire path is a shellout, gated on platform here so that the
      # plugin's dispatch in Lune::Native::Notifications.show stays uniform.
      module Notifications
        def self.show(title : String, body : String)
          # Title/body travel via env vars so we don't have to escape them
          # into the command line; PowerShell's SecurityElement.Escape handles
          # XML escaping inside the script.
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
        end
      end
    end
  end
{% end %}
