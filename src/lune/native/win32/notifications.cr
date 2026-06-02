{% if flag?(:win32) && !flag?(:lune_native_test_mock) %}
  # Crystal's stdlib `LibC` already declares `CreateProcessW`,
  # `WaitForSingleObject`, `GetExitCodeProcess`, `CloseHandle`, the
  # `STARTUPINFOW` / `PROCESS_INFORMATION` structs, and `CREATE_UNICODE_ENVIRONMENT`.
  # `CREATE_NO_WINDOW` is the one piece missing — add it so we can pass it through.
  lib LibC
    CREATE_NO_WINDOW = 0x08000000
  end

  module Lune
    module Native
      # Win32 toast notifications via PowerShell + WinRT. The entire path is a
      # shellout, gated on platform here so the plugin's dispatch in
      # `Lune::Native::Notifications.show` stays uniform.
      #
      # We call `CreateProcessW` directly so we can pass `CREATE_NO_WINDOW`.
      # `Process.run` doesn't expose creation flags; since lune.exe is
      # `/subsystem:windows` (no console), spawning `powershell.exe` without
      # the flag makes Windows allocate a fresh console for it, and
      # `-WindowStyle Hidden` only takes effect *after* PowerShell parses its
      # args — long enough for a console to flash on every toast.
      module Notifications
        # MSDN AUMID grammar: 1-129 chars, ASCII alphanumerics + "." + "\",
        # where backslash separates up to 4 parts of ≤50 chars each. We only
        # emit a single part (no company.product split), so just strip
        # whitespace/punctuation and clamp to 50 chars. Empty → "Lune".
        private def self.aumid_from(name : String) : String
          clean = name.gsub(/[^A-Za-z0-9.]/, "")
          clean = clean[0, 50]
          clean.empty? ? "Lune" : clean
        end

        AUMID = aumid_from(Lune::APP_NAME)

        def self.show(title : String, body : String)
          # Title/body travel via env vars so we don't have to escape them into
          # the command line; PowerShell's SecurityElement.Escape handles XML
          # escaping inside the script.
          #
          # AUMID registration via HKCU\Software\Classes\AppUserModelId is the
          # Microsoft-documented path for non-UWP desktop apps to receive toasts
          # (see learn.microsoft.com → "Send a local toast notification from
          # other types of unpackaged apps"). The key only needs to exist once
          # per user; we Test-Path and skip the write on subsequent calls.
          # Without this, Windows silently drops the toast even when the WinRT
          # call returns success.
          #
          # Two separate WinRT projections need explicit loading: loading
          # Windows.UI.Notifications alone doesn't make Windows.Data.Xml.Dom
          # available, and New-Object on XmlDocument fails with TypeNotFound.
          script = <<-PS
            $aumid = "#{AUMID}"
            $displayName = $env:LUNE_TOAST_DISPLAY_NAME
            $aumidKey = "HKCU:\\SOFTWARE\\Classes\\AppUserModelId\\$aumid"
            if (-not (Test-Path $aumidKey)) {
                New-Item -Path $aumidKey -Force | Out-Null
                Set-ItemProperty -Path $aumidKey -Name "DisplayName" -Value $displayName -Type String
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

          # Both buffers stay live in this scope across the synchronous
          # `CreateProcessW` so the underlying `Slice(UInt16)` storage doesn't
          # get collected mid-call.
          cmdline_utf16 = build_command_line(script)
          env_utf16 = build_env_block({
            "LUNE_TOAST_TITLE"        => title,
            "LUNE_TOAST_BODY"         => body,
            "LUNE_TOAST_DISPLAY_NAME" => Lune::APP_NAME,
          })

          si = LibC::STARTUPINFOW.new
          si.cb = sizeof(LibC::STARTUPINFOW).to_u32
          pi = LibC::PROCESS_INFORMATION.new

          ok = LibC.CreateProcessW(
            nil,
            cmdline_utf16.to_unsafe,
            nil,
            nil,
            0,
            (LibC::CREATE_NO_WINDOW | LibC::CREATE_UNICODE_ENVIRONMENT).to_u32,
            env_utf16.to_unsafe.as(Void*),
            nil,
            pointerof(si),
            pointerof(pi),
          )

          if ok == 0
            Lune.logger.warn { "Notifications: CreateProcessW(powershell) failed" }
            return nil
          end

          LibC.WaitForSingleObject(pi.hProcess, LibC::INFINITE)
          exit_code = 0_u32
          LibC.GetExitCodeProcess(pi.hProcess, pointerof(exit_code))
          LibC.CloseHandle(pi.hProcess)
          LibC.CloseHandle(pi.hThread)
          Lune.logger.warn { "Notifications: powershell exited with code=#{exit_code}" } unless exit_code == 0
          nil
        end

        # `lpCommandLine` is mutable for `CreateProcessW`, so we build a fresh
        # UTF-16 buffer each call. argv[0] needs no escaping (`powershell` is a
        # bare token); the script body becomes one quoted argument whose embedded
        # double-quotes are CommandLineToArgvW-escaped (`"` → `\"`).
        private def self.build_command_line(script : String) : Slice(UInt16)
          escaped = script.gsub('"', %q(\"))
          cmd = %(powershell -NoProfile -NonInteractive -WindowStyle Hidden -Command "#{escaped}")
          cmd.to_utf16
        end

        # A `CREATE_UNICODE_ENVIRONMENT` block: parent env merged with our
        # `LUNE_TOAST_*` overrides, then encoded as one UTF-16 buffer of
        # `KEY=VALUE\0` entries with an extra `\0` terminator.
        private def self.build_env_block(extras : Hash(String, String)) : Slice(UInt16)
          merged = parent_env_pairs
          extras.each { |k, v| merged[k] = v }
          # `\0`-joined entries + a trailing `\0` becomes `…last_value\0\0` after
          # encoding — the block-terminator the OS expects.
          joined = merged.map { |k, v| "#{k}=#{v}" }.join('\0') + "\0\0"
          joined.to_utf16
        end

        private def self.parent_env_pairs : Hash(String, String)
          block = LibC.GetEnvironmentStringsW
          return {} of String => String if block.null?
          pairs = {} of String => String
          cursor = block
          loop do
            len = 0
            while cursor[len] != 0_u16
              len += 1
            end
            break if len == 0
            entry = String.from_utf16(cursor.to_slice(len))
            if (eq = entry.index('=')) && eq > 0
              pairs[entry[0, eq]] = entry[(eq + 1)..]
            end
            cursor += len + 1
          end
          LibC.FreeEnvironmentStringsW(block)
          pairs
        end
      end
    end
  end
{% end %}
