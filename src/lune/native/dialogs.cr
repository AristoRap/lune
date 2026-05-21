module Lune
  module Native
    # Platform lib blocks + mock live in sibling subdirs:
    #   - mock/dialogs.cr     DialogsMock module
    #   - darwin/dialogs.cr   LibNativeDialogs (NSOpenPanel / NSSavePanel)
    #   - linux/dialogs.cr    LibNativeDialogs (GtkFileChooser)
    #   - win32/dialogs.cr    LibComDlg32 + LibShell32Dialog + LibUser32Dialog
    module Dialogs
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
          DialogsMock.record_open(title)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          buf = Bytes.new(PATH_BUF_SIZE)
          if LibNativeDialogs.open_file_dialog(title, buf.to_unsafe.as(LibC::Char*), PATH_BUF_SIZE) == 1
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
          DialogsMock.record_open_dir(title)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          buf = Bytes.new(PATH_BUF_SIZE)
          if LibNativeDialogs.open_dir_dialog(title, buf.to_unsafe.as(LibC::Char*), PATH_BUF_SIZE) == 1
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
          DialogsMock.record_open_files(title)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          buf = Bytes.new(PATHS_BUF_SIZE)
          if LibNativeDialogs.open_files_dialog(title, buf.to_unsafe.as(LibC::Char*), PATHS_BUF_SIZE) == 1
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
        {% else %}
          [] of String
        {% end %}
      end

      def self.save_file(title : String, default_name : String = "") : String?
        {% if flag?(:lune_native_test_mock) %}
          DialogsMock.record_save(title, default_name)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          buf = Bytes.new(PATH_BUF_SIZE)
          if LibNativeDialogs.save_file_dialog(title, default_name, buf.to_unsafe.as(LibC::Char*), PATH_BUF_SIZE) == 1
            String.new(buf.to_unsafe)
          end
        {% elsif flag?(:win32) %}
          ofn, buf = make_ofn(title, default_name, LibComDlg32::OFN_OVERWRITEPROMPT)
          return nil if LibComDlg32.get_save_file_name_w(pointerof(ofn)) == 0
          from_wstr(buf)
        {% end %}
      end

      # type code maps the dialog kind; matches the macOS/Linux native shim and
      # the capability layer (see src/lune/capabilities/dialogs.cr):
      #   0 = info, 1 = warning, 2 = error, 3 = question (yes/no).
      # info/warning/error are notification-style dialogs (single OK button,
      # icon distinguishes severity); question is the only variant that
      # returns a meaningful Yes/No.
      def self.message(type : Int32, title : String, message : String) : String
        {% if flag?(:lune_native_test_mock) %}
          DialogsMock.record_message(type, title)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          buf = Bytes.new(16)
          LibNativeDialogs.message_dialog(type, title, message, buf.to_unsafe.as(LibC::Char*), 16)
          String.new(buf.to_unsafe)
        {% elsif flag?(:win32) %}
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
        {% else %}
          "Ok"
        {% end %}
      end
    end
  end
end
