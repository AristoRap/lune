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
    end
  end
{% end %}
