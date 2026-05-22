{% if flag?(:win32) && !flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      @[Link("comdlg32")]
      lib LibComDlg32
        OFN_PATHMUSTEXIST    = 0x0000_0800_u32
        OFN_FILEMUSTEXIST    = 0x0000_1000_u32
        OFN_ALLOWMULTISELECT = 0x0000_0200_u32
        OFN_EXPLORER         = 0x0008_0000_u32
        OFN_HIDEREADONLY     = 0x0000_0004_u32
        OFN_OVERWRITEPROMPT  = 0x0000_0002_u32

        # Sized for x64. On Win32 (32-bit) some pointer-sized fields would be
        # 4 bytes — Lune is x64-only on Windows for v0.10.0.
        struct OpenFileNameW
          struct_size : UInt32
          h_wnd_owner : Void*
          h_instance : Void*
          filter : UInt16*
          custom_filter : UInt16*
          max_custom_filter : UInt32
          filter_index : UInt32
          file : UInt16*
          max_file : UInt32
          file_title : UInt16*
          max_file_title : UInt32
          initial_dir : UInt16*
          title : UInt16*
          flags : UInt32
          file_offset : UInt16
          file_extension : UInt16
          def_ext : UInt16*
          cust_data : Void*
          fn_hook : Void*
          template_name : UInt16*
          # Vista+ fields
          pv_reserved : Void*
          dw_reserved : UInt32
          flags_ex : UInt32
        end

        fun get_open_file_name_w = GetOpenFileNameW(ofn : OpenFileNameW*) : LibC::Int
        fun get_save_file_name_w = GetSaveFileNameW(ofn : OpenFileNameW*) : LibC::Int
      end

      @[Link("shell32")]
      lib LibShell32Dialog
        BIF_RETURNONLYFSDIRS = 0x0000_0001_u32
        BIF_USENEWUI         = 0x0000_0050_u32

        struct BrowseInfoW
          h_wnd_owner : Void*
          pidl_root : Void*
          display_name : UInt16*
          title : UInt16*
          flags : UInt32
          fn_callback : Void*
          l_param : LibC::Long
          i_image : LibC::Int
        end

        fun sh_browse_for_folder_w = SHBrowseForFolderW(info : BrowseInfoW*) : Void*
        fun sh_get_path_from_id_list_w = SHGetPathFromIDListW(pidl : Void*, path : UInt16*) : LibC::Int
        fun co_task_mem_free = CoTaskMemFree(pv : Void*) : Void
      end

      @[Link("user32")]
      lib LibUser32Dialog
        MB_OK              =  0x0_u32
        MB_OKCANCEL        =  0x1_u32
        MB_YESNO           =  0x4_u32
        MB_ICONERROR       = 0x10_u32
        MB_ICONQUESTION    = 0x20_u32
        MB_ICONWARNING     = 0x30_u32
        MB_ICONINFORMATION = 0x40_u32

        IDOK     = 1
        IDCANCEL = 2
        IDYES    = 6
        IDNO     = 7

        fun message_box_w = MessageBoxW(hwnd : Void*, text : UInt16*, caption : UInt16*, type : UInt32) : LibC::Int
      end

      module Dialogs
        # Null-terminated UTF-16 buffer for Win32 W-suffix APIs.
        private def self.to_wstr(s : String) : UInt16*
          arr = s.to_utf16
          buf = Pointer(UInt16).malloc(arr.size + 1)
          arr.size.times { |i| buf[i] = arr[i] }
          buf[arr.size] = 0_u16
          buf
        end

        # Read a UTF-16 null-terminated string from a heap pointer.
        private def self.from_wstr(ptr : UInt16*) : String
          len = 0
          while ptr[len] != 0_u16
            len += 1
          end
          String.from_utf16(Slice.new(ptr, len))
        end

        # Build the standard OPENFILENAMEW struct used by both
        # GetOpenFileNameW and GetSaveFileNameW. Caller owns the lifetime of
        # the buffer pointer returned in the tuple — keep `buf` alive until
        # after the dialog call returns.
        private def self.make_ofn(title : String, default_name : String, flags : UInt32) : {LibComDlg32::OpenFileNameW, Pointer(UInt16)}
          # 1 MB scratch buffer fits any reasonable single-select result and
          # an OFN_ALLOWMULTISELECT result with hundreds of files.
          buf = Pointer(UInt16).malloc(PATHS_BUF_SIZE)
          if default_name.empty?
            buf[0] = 0_u16
          else
            arr = default_name.to_utf16
            arr.size.times { |i| buf[i] = arr[i] }
            buf[arr.size] = 0_u16
          end
          ofn = LibComDlg32::OpenFileNameW.new
          ofn.struct_size = sizeof(LibComDlg32::OpenFileNameW).to_u32
          ofn.file = buf
          ofn.max_file = PATHS_BUF_SIZE.to_u32
          ofn.title = to_wstr(title)
          ofn.flags = flags | LibComDlg32::OFN_EXPLORER | LibComDlg32::OFN_HIDEREADONLY
          {ofn, buf}
        end

        def self.open_file(title : String) : String?
          ofn, buf = make_ofn(title, "", LibComDlg32::OFN_PATHMUSTEXIST | LibComDlg32::OFN_FILEMUSTEXIST)
          return nil if LibComDlg32.get_open_file_name_w(pointerof(ofn)) == 0
          from_wstr(buf)
        end

        def self.open_dir(title : String) : String?
          info = LibShell32Dialog::BrowseInfoW.new
          info.title = to_wstr(title)
          info.flags = LibShell32Dialog::BIF_RETURNONLYFSDIRS | LibShell32Dialog::BIF_USENEWUI
          pidl = LibShell32Dialog.sh_browse_for_folder_w(pointerof(info))
          return nil if pidl.null?
          path_buf = Pointer(UInt16).malloc(PATH_BUF_SIZE)
          ok = LibShell32Dialog.sh_get_path_from_id_list_w(pidl, path_buf)
          LibShell32Dialog.co_task_mem_free(pidl)
          ok == 0 ? nil : from_wstr(path_buf)
        end

        def self.open_files(title : String) : Array(String)
          ofn, buf = make_ofn(title, "",
            LibComDlg32::OFN_PATHMUSTEXIST | LibComDlg32::OFN_FILEMUSTEXIST |
            LibComDlg32::OFN_ALLOWMULTISELECT)
          return [] of String if LibComDlg32.get_open_file_name_w(pointerof(ofn)) == 0
          # Multi-select result is a null-separated list: [dir, file1, file2, ...]
          # terminated by a double-null. If only one file selected, buf contains
          # just the full path (no null separators).
          segments = [] of String
          i = 0
          loop do
            j = i
            while buf[j] != 0_u16
              j += 1
            end
            break if j == i
            segments << String.from_utf16(Slice.new(buf + i, j - i))
            i = j + 1
          end
          return [] of String if segments.empty?
          return segments if segments.size == 1
          dir = segments[0]
          segments[1..].map { |name| File.join(dir, name) }
        end

        def self.save_file(title : String, default_name : String = "") : String?
          ofn, buf = make_ofn(title, default_name, LibComDlg32::OFN_OVERWRITEPROMPT)
          return nil if LibComDlg32.get_save_file_name_w(pointerof(ofn)) == 0
          from_wstr(buf)
        end

        def self.message(type : Int32, title : String, message : String) : String
          flags = case type
                  when 1 then LibUser32Dialog::MB_OK | LibUser32Dialog::MB_ICONWARNING
                  when 2 then LibUser32Dialog::MB_OK | LibUser32Dialog::MB_ICONERROR
                  when 3 then LibUser32Dialog::MB_YESNO | LibUser32Dialog::MB_ICONQUESTION
                  else        LibUser32Dialog::MB_OK | LibUser32Dialog::MB_ICONINFORMATION
                  end
          result = LibUser32Dialog.message_box_w(Pointer(Void).null, to_wstr(message), to_wstr(title), flags)
          case result
          when LibUser32Dialog::IDOK     then "Ok"
          when LibUser32Dialog::IDCANCEL then "Cancel"
          when LibUser32Dialog::IDYES    then "Yes"
          when LibUser32Dialog::IDNO     then "No"
          else                                "Ok"
          end
        end
      end
    end
  end
{% end %}
