{% if flag?(:win32) && !flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      # Crystal's stdlib already binds RegCloseKey / RegOpenKeyExW in LibC;
      # we only add the two write-side functions it doesn't expose.
      @[Link("advapi32")]
      lib LibAdvapi32UrlScheme
        fun reg_create_key_ex_w = RegCreateKeyExW(
          h_key : LibC::HKEY,
          lp_sub_key : LibC::LPWSTR,
          reserved : LibC::DWORD,
          lp_class : LibC::LPWSTR,
          dw_options : LibC::DWORD,
          sam_desired : LibC::REGSAM,
          lp_security_attributes : Void*,
          phk_result : LibC::HKEY*,
          lp_disposition : LibC::DWORD*
        ) : LibC::LSTATUS

        fun reg_set_value_ex_w = RegSetValueExW(
          h_key : LibC::HKEY,
          lp_value_name : LibC::LPWSTR,
          reserved : LibC::DWORD,
          dw_type : LibC::DWORD,
          lp_data : UInt8*,
          cb_data : LibC::DWORD
        ) : LibC::LSTATUS
      end

      # Per-user URL-scheme registration via HKCU\Software\Classes\<scheme>.
      # Idempotent: rewrites the same keys on every call, so a moved or
      # renamed exe self-heals on next launch.
      #
      # No admin required — HKCU is writable by the current user. The OS
      # consults HKCU before HKLM, so a per-user entry overrides any
      # per-machine one for the same scheme.
      module UrlScheme
        # REGSAM bitmask for KEY_WRITE (STANDARD_RIGHTS_WRITE | SET_VALUE |
        # CREATE_SUB_KEY). Crystal's REGSAM enum lists the individual bits;
        # KEY_WRITE itself isn't named, so we pass the literal value.
        KEY_WRITE =  0x20006
        REG_SZ    = 1_u32

        def self.register(scheme : String, exe_path : String, display : String) : Bool
          base = "Software\\Classes\\#{scheme}"
          # The empty "URL Protocol" value is the marker Windows uses to
          # distinguish a URL-scheme key from a regular file-association key.
          return false unless write_key(base, "", "URL:#{display}")
          return false unless write_key(base, "URL Protocol", "")
          # %1 is the URL passed by the shell when the scheme is invoked.
          write_key("#{base}\\shell\\open\\command", "", %("#{exe_path}" "%1"))
        end

        private def self.write_key(subkey : String, value_name : String, value : String) : Bool
          key_handle = uninitialized LibC::HKEY
          rc = LibAdvapi32UrlScheme.reg_create_key_ex_w(
            LibC::HKEY_CURRENT_USER, utf16z(subkey), 0_u32,
            Pointer(UInt16).null, 0_u32,
            LibC::REGSAM.new(KEY_WRITE), Pointer(Void).null,
            pointerof(key_handle), Pointer(LibC::DWORD).null
          )
          return false unless rc == 0

          begin
            name_w = value_name.empty? ? Pointer(UInt16).null : utf16z(value_name)
            data_w = utf16z(value)
            byte_len = (value.size + 1) * 2
            rc = LibAdvapi32UrlScheme.reg_set_value_ex_w(
              key_handle, name_w, 0_u32, REG_SZ,
              data_w.as(UInt8*), byte_len.to_u32
            )
            rc == 0
          ensure
            LibC.RegCloseKey(key_handle)
          end
        end

        private def self.utf16z(s : String) : UInt16*
          slice = s.to_utf16
          buf = GC.malloc_atomic((slice.size + 1) * 2).as(UInt16*)
          slice.each_with_index { |c, i| buf[i] = c }
          buf[slice.size] = 0_u16
          buf
        end
      end
    end
  end
{% end %}
