module Lune
  module Native
    {% if flag?(:lune_native_test_mock) %}
      module DialogMock
        record Call, method : Symbol, title : String, default_name : String = ""

        @@calls = [] of Call
        @@next_open_result : String? = nil
        @@next_open_dir_result : String? = nil
        @@next_open_files_result : Array(String) = [] of String
        @@next_save_result : String? = nil
        @@next_message_result : String = "Ok"

        class_getter calls

        def self.reset
          @@calls.clear
          @@next_open_result = nil
          @@next_open_dir_result = nil
          @@next_open_files_result = [] of String
          @@next_save_result = nil
          @@next_message_result = "Ok"
        end

        def self.stub_open(path : String?);              @@next_open_result = path; end
        def self.stub_open_dir(path : String?);          @@next_open_dir_result = path; end
        def self.stub_open_files(paths : Array(String)); @@next_open_files_result = paths; end
        def self.stub_save(path : String?);              @@next_save_result = path; end
        def self.stub_message(result : String);          @@next_message_result = result; end

        def self.record_open(title : String) : String?
          @@calls << Call.new(:open_file, title)
          @@next_open_result
        end

        def self.record_open_dir(title : String) : String?
          @@calls << Call.new(:open_dir, title)
          @@next_open_dir_result
        end

        def self.record_open_files(title : String) : Array(String)
          @@calls << Call.new(:open_files, title)
          @@next_open_files_result
        end

        def self.record_save(title : String, default_name : String) : String?
          @@calls << Call.new(:save_file, title, default_name)
          @@next_save_result
        end

        def self.record_message(type : Int32, title : String) : String
          @@calls << Call.new(:message, title)
          @@next_message_result
        end
      end
    {% elsif flag?(:darwin) %}
      {% system("cd '#{__DIR__}/../../../ext/native/macos' && clang -c dialog.m -o dialog.o -fobjc-arc 2>/dev/null") %}

      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../ext/native/macos/dialog.o")]
      lib LibNativeDialog
        fun open_file_dialog(title : LibC::Char*, out : LibC::Char*, out_size : LibC::Int) : LibC::Int
        fun open_dir_dialog(title : LibC::Char*, out : LibC::Char*, out_size : LibC::Int) : LibC::Int
        fun open_files_dialog(title : LibC::Char*, out : LibC::Char*, out_size : LibC::Int) : LibC::Int
        fun save_file_dialog(title : LibC::Char*, default_name : LibC::Char*, out : LibC::Char*, out_size : LibC::Int) : LibC::Int
        fun message_dialog(type : LibC::Int, title : LibC::Char*, message : LibC::Char*, out : LibC::Char*, out_size : LibC::Int) : LibC::Int
      end
    {% elsif flag?(:linux) %}
      {% system("cd '#{__DIR__}/../../../ext/native/linux' && gcc -c dialog.c -o dialog.o `pkg-config --cflags gtk+-3.0` 2>/dev/null") %}

      @[Link(ldflags: "#{__DIR__}/../../../ext/native/linux/dialog.o")]
      @[Link(ldflags: "`pkg-config --libs gtk+-3.0`")]
      lib LibNativeDialog
        fun open_file_dialog(title : LibC::Char*, out : LibC::Char*, out_size : LibC::Int) : LibC::Int
        fun open_dir_dialog(title : LibC::Char*, out : LibC::Char*, out_size : LibC::Int) : LibC::Int
        fun open_files_dialog(title : LibC::Char*, out : LibC::Char*, out_size : LibC::Int) : LibC::Int
        fun save_file_dialog(title : LibC::Char*, default_name : LibC::Char*, out : LibC::Char*, out_size : LibC::Int) : LibC::Int
        fun message_dialog(type : LibC::Int, title : LibC::Char*, message : LibC::Char*, out : LibC::Char*, out_size : LibC::Int) : LibC::Int
      end
    {% elsif flag?(:win32) %}
      @[Link("comdlg32")]
      lib LibComDlg32
        OFN_PATHMUSTEXIST   = 0x0000_0800_u32
        OFN_FILEMUSTEXIST   = 0x0000_1000_u32
        OFN_ALLOWMULTISELECT = 0x0000_0200_u32
        OFN_EXPLORER        = 0x0008_0000_u32
        OFN_HIDEREADONLY    = 0x0000_0004_u32
        OFN_OVERWRITEPROMPT = 0x0000_0002_u32

        # Sized for x64. On Win32 (32-bit) some pointer-sized fields would be
        # 4 bytes — Lune is x64-only on Windows for v0.10.0.
        struct OpenFileNameW
          struct_size      : UInt32
          h_wnd_owner      : Void*
          h_instance       : Void*
          filter           : UInt16*
          custom_filter    : UInt16*
          max_custom_filter : UInt32
          filter_index     : UInt32
          file             : UInt16*
          max_file         : UInt32
          file_title       : UInt16*
          max_file_title   : UInt32
          initial_dir      : UInt16*
          title            : UInt16*
          flags            : UInt32
          file_offset      : UInt16
          file_extension   : UInt16
          def_ext          : UInt16*
          cust_data        : Void*
          fn_hook          : Void*
          template_name    : UInt16*
          # Vista+ fields
          pv_reserved      : Void*
          dw_reserved      : UInt32
          flags_ex         : UInt32
        end

        fun get_open_file_name_w = GetOpenFileNameW(ofn : OpenFileNameW*) : LibC::Int
        fun get_save_file_name_w = GetSaveFileNameW(ofn : OpenFileNameW*) : LibC::Int
      end

      @[Link("shell32")]
      lib LibShell32Dialog
        BIF_RETURNONLYFSDIRS  = 0x0000_0001_u32
        BIF_USENEWUI          = 0x0000_0050_u32

        struct BrowseInfoW
          h_wnd_owner   : Void*
          pidl_root     : Void*
          display_name  : UInt16*
          title         : UInt16*
          flags         : UInt32
          fn_callback   : Void*
          l_param       : LibC::Long
          i_image       : LibC::Int
        end

        fun sh_browse_for_folder_w = SHBrowseForFolderW(info : BrowseInfoW*) : Void*
        fun sh_get_path_from_id_list_w = SHGetPathFromIDListW(pidl : Void*, path : UInt16*) : LibC::Int
        fun co_task_mem_free = CoTaskMemFree(pv : Void*) : Void
      end

      @[Link("user32")]
      lib LibUser32Dialog
        MB_OK                = 0x0_u32
        MB_OKCANCEL          = 0x1_u32
        MB_YESNO             = 0x4_u32
        MB_ICONERROR         = 0x10_u32
        MB_ICONQUESTION      = 0x20_u32
        MB_ICONWARNING       = 0x30_u32
        MB_ICONINFORMATION   = 0x40_u32

        IDOK     =  1
        IDCANCEL =  2
        IDYES    =  6
        IDNO     =  7

        fun message_box_w = MessageBoxW(hwnd : Void*, text : UInt16*, caption : UInt16*, type : UInt32) : LibC::Int
      end
    {% end %}

    module Dialog
      PATH_BUF_SIZE  =  4096
      PATHS_BUF_SIZE = 65536

      {% if flag?(:win32) %}
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
      {% end %}

      def self.open_file(title : String) : String?
        {% if flag?(:lune_native_test_mock) %}
          DialogMock.record_open(title)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          buf = Bytes.new(PATH_BUF_SIZE)
          if LibNativeDialog.open_file_dialog(title, buf.to_unsafe.as(LibC::Char*), PATH_BUF_SIZE) == 1
            String.new(buf.to_unsafe)
          end
        {% elsif flag?(:win32) %}
          ofn, buf = make_ofn(title, "", LibComDlg32::OFN_PATHMUSTEXIST | LibComDlg32::OFN_FILEMUSTEXIST)
          return nil if LibComDlg32.get_open_file_name_w(pointerof(ofn)) == 0
          from_wstr(buf)
        {% end %}
      end

      def self.open_dir(title : String) : String?
        {% if flag?(:lune_native_test_mock) %}
          DialogMock.record_open_dir(title)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          buf = Bytes.new(PATH_BUF_SIZE)
          if LibNativeDialog.open_dir_dialog(title, buf.to_unsafe.as(LibC::Char*), PATH_BUF_SIZE) == 1
            String.new(buf.to_unsafe)
          end
        {% elsif flag?(:win32) %}
          info = LibShell32Dialog::BrowseInfoW.new
          info.title = to_wstr(title)
          info.flags = LibShell32Dialog::BIF_RETURNONLYFSDIRS | LibShell32Dialog::BIF_USENEWUI
          pidl = LibShell32Dialog.sh_browse_for_folder_w(pointerof(info))
          return nil if pidl.null?
          path_buf = Pointer(UInt16).malloc(PATH_BUF_SIZE)
          ok = LibShell32Dialog.sh_get_path_from_id_list_w(pidl, path_buf)
          LibShell32Dialog.co_task_mem_free(pidl)
          ok == 0 ? nil : from_wstr(path_buf)
        {% end %}
      end

      def self.open_files(title : String) : Array(String)
        {% if flag?(:lune_native_test_mock) %}
          DialogMock.record_open_files(title)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          buf = Bytes.new(PATHS_BUF_SIZE)
          if LibNativeDialog.open_files_dialog(title, buf.to_unsafe.as(LibC::Char*), PATHS_BUF_SIZE) == 1
            String.new(buf.to_unsafe).split('\n').reject(&.empty?)
          else
            [] of String
          end
        {% elsif flag?(:win32) %}
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
            j += 1 while buf[j] != 0_u16
            break if j == i
            segments << String.from_utf16(Slice.new(buf + i, j - i))
            i = j + 1
          end
          return [] of String if segments.empty?
          return segments if segments.size == 1
          dir = segments[0]
          segments[1..].map { |name| File.join(dir, name) }
        {% else %}
          [] of String
        {% end %}
      end

      def self.save_file(title : String, default_name : String = "") : String?
        {% if flag?(:lune_native_test_mock) %}
          DialogMock.record_save(title, default_name)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          buf = Bytes.new(PATH_BUF_SIZE)
          if LibNativeDialog.save_file_dialog(title, default_name, buf.to_unsafe.as(LibC::Char*), PATH_BUF_SIZE) == 1
            String.new(buf.to_unsafe)
          end
        {% elsif flag?(:win32) %}
          ofn, buf = make_ofn(title, default_name, LibComDlg32::OFN_OVERWRITEPROMPT)
          return nil if LibComDlg32.get_save_file_name_w(pointerof(ofn)) == 0
          from_wstr(buf)
        {% end %}
      end

      # type code maps the dialog kind; matches the macOS/Linux native shim:
      # 0 = info, 1 = question (yes/no), 2 = warning (ok/cancel), 3 = error.
      def self.message(type : Int32, title : String, message : String) : String
        {% if flag?(:lune_native_test_mock) %}
          DialogMock.record_message(type, title)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          buf = Bytes.new(16)
          LibNativeDialog.message_dialog(type, title, message, buf.to_unsafe.as(LibC::Char*), 16)
          String.new(buf.to_unsafe)
        {% elsif flag?(:win32) %}
          flags = case type
                  when 1 then LibUser32Dialog::MB_YESNO | LibUser32Dialog::MB_ICONQUESTION
                  when 2 then LibUser32Dialog::MB_OKCANCEL | LibUser32Dialog::MB_ICONWARNING
                  when 3 then LibUser32Dialog::MB_OK | LibUser32Dialog::MB_ICONERROR
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
        {% else %}
          "Ok"
        {% end %}
      end
    end
  end
end
