{% if flag?(:win32) && !flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      @[Link("user32")]
      lib LibUser32Menu
        MF_STRING    = 0x0000_u32
        MF_SEPARATOR = 0x0800_u32
        MF_GRAYED    = 0x0001_u32
        MF_CHECKED   = 0x0008_u32

        TPM_RETURNCMD   = 0x0100_u32
        TPM_NONOTIFY    = 0x0080_u32
        TPM_RIGHTBUTTON = 0x0002_u32

        struct Point
          x : LibC::Long
          y : LibC::Long
        end

        fun create_popup_menu = CreatePopupMenu : Void*
        fun destroy_menu = DestroyMenu(menu : Void*) : LibC::Int
        fun append_menu_w = AppendMenuW(menu : Void*, flags : UInt32, id : LibC::ULong, item : UInt16*) : LibC::Int
        fun track_popup_menu = TrackPopupMenu(menu : Void*, flags : UInt32, x : LibC::Int, y : LibC::Int, reserved : LibC::Int, hwnd : Void*, rect : Void*) : LibC::Int
        fun client_to_screen = ClientToScreen(hwnd : Void*, pt : Point*) : LibC::Int
        fun set_foreground_window = SetForegroundWindow(hwnd : Void*) : LibC::Int
      end

      module Menu
        # App menu (setup_default / set_from_options) is not wired on Win32.
        def self.setup_default(app_name : String); end

        def self.set_from_options(opts : Options::Menu, app_name : String); end

        # Parse the JSON shape used by Lune::Plugins::ContextMenu —
        # an array of {id, label, enabled?} or {kind: "separator"}.
        # Build a popup menu, track it modally, and translate the result
        # back to the user's item id via a Crystal-side id→string map.
        def self.show_context_menu(handle : Void*, x : Float32, y : Float32, items_json : String, &on_select : String -> Nil)
          cb = on_select
          items = begin
            JSON.parse(items_json).as_a
          rescue
            return
          end

          menu = LibUser32Menu.create_popup_menu
          return if menu.null?

          id_map = {} of LibC::ULong => String
          next_cmd : LibC::ULong = 1_u64
          items.each do |item|
            obj = item.as_h?
            next unless obj
            if obj["kind"]?.try(&.as_s) == "separator"
              LibUser32Menu.append_menu_w(menu, LibUser32Menu::MF_SEPARATOR, 0_u64, Pointer(UInt16).null)
              next
            end
            id = obj["id"]?.try(&.as_s) || ""
            label = obj["label"]?.try(&.as_s) || id
            enabled = obj["enabled"]?.try(&.as_bool?) != false
            flags = LibUser32Menu::MF_STRING
            flags |= LibUser32Menu::MF_GRAYED unless enabled
            arr = label.to_utf16
            buf = Pointer(UInt16).malloc(arr.size + 1)
            arr.size.times { |i| buf[i] = arr[i] }
            buf[arr.size] = 0_u16
            cmd = next_cmd
            next_cmd += 1
            id_map[cmd] = id
            LibUser32Menu.append_menu_w(menu, flags, cmd, buf)
          end

          # Translate webview client coords to screen coords. `handle` is the
          # top-level window HWND from wv.native_handle(UI_WINDOW); the
          # webview content lives in a child HWND, but ClientToScreen on the
          # parent is close enough for picker placement — fine alignment
          # will require WV2's controller HWND.
          pt = LibUser32Menu::Point.new
          pt.x = x.to_i64
          pt.y = y.to_i64
          LibUser32Menu.client_to_screen(handle, pointerof(pt))

          # Per MSDN, the owner window must be foreground for TrackPopupMenu
          # to dismiss correctly when the user clicks outside the menu.
          LibUser32Menu.set_foreground_window(handle)
          cmd_chosen = LibUser32Menu.track_popup_menu(menu,
            LibUser32Menu::TPM_RETURNCMD | LibUser32Menu::TPM_NONOTIFY | LibUser32Menu::TPM_RIGHTBUTTON,
            pt.x.to_i32, pt.y.to_i32, 0, handle, Pointer(Void).null)
          LibUser32Menu.destroy_menu(menu)

          if id = id_map[cmd_chosen.to_u64]?
            cb.call(id)
          end
        end
      end
    end
  end
{% end %}
