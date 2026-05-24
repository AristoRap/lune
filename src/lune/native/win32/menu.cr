{% if flag?(:win32) && !flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      @[Link("user32")]
      lib LibUser32Menu
        MF_STRING    = 0x0000_u32
        MF_SEPARATOR = 0x0800_u32
        MF_GRAYED    = 0x0001_u32
        MF_CHECKED   = 0x0008_u32
        MF_POPUP     = 0x0010_u32

        TPM_RETURNCMD   = 0x0100_u32
        TPM_NONOTIFY    = 0x0080_u32
        TPM_RIGHTBUTTON = 0x0002_u32

        struct Point
          x : LibC::Long
          y : LibC::Long
        end

        fun create_menu = CreateMenu : Void*
        fun create_popup_menu = CreatePopupMenu : Void*
        fun destroy_menu = DestroyMenu(menu : Void*) : LibC::Int
        fun append_menu_w = AppendMenuW(menu : Void*, flags : UInt32, id : LibC::ULong, item : UInt16*) : LibC::Int
        fun track_popup_menu = TrackPopupMenu(menu : Void*, flags : UInt32, x : LibC::Int, y : LibC::Int, reserved : LibC::Int, hwnd : Void*, rect : Void*) : LibC::Int
        fun client_to_screen = ClientToScreen(hwnd : Void*, pt : Point*) : LibC::Int
        fun set_foreground_window = SetForegroundWindow(hwnd : Void*) : LibC::Int
        fun set_menu = SetMenu(hwnd : Void*, menu : Void*) : LibC::Int
        fun get_menu = GetMenu(hwnd : Void*) : Void*
        fun draw_menu_bar = DrawMenuBar(hwnd : Void*) : LibC::Int
        fun check_menu_radio_item = CheckMenuRadioItem(menu : Void*, first : UInt32, last : UInt32, check : UInt32, flags : UInt32) : LibC::Int
      end

      module Menu
        # Per-HWND HMENU we built and attached, kept alive so a follow-up
        # `set_from_options` (e.g. `app.update_menu`) can destroy the prior
        # tree before swapping in a new one. The HMENU is also reachable via
        # `GetMenu(hwnd)` but tracking it here avoids relying on the win32
        # call returning the exact pointer we built.
        @@current_menus = {} of Void* => Void*

        # No window menu by default on Windows — most desktop apps don't have
        # one, and macOS's "App | Edit" template (Quit / Cut / Copy / Paste /
        # Select All) maps to OS conventions Windows doesn't share. Apps that
        # want a menu set one explicitly via `opts.menu { … }`.
        def self.setup_default(handle : Void*, app_name : String); end

        # Build an HMENU from the same JSON shape darwin's NSMenu builder
        # consumes, then `SetMenu` it on the window. Each clickable item gets
        # a fresh command ID (1-indexed); on click the WindowProc trampoline
        # (in win32/window.cr) routes WM_COMMAND back to the registered
        # callback. RoleApp / RoleEdit are no-ops — macOS-only concepts.
        #
        # Accelerator strings (`"cmd+p"`) are rendered as right-aligned hint
        # text after a `\t` separator (e.g. "Pause Clock\tCtrl+P") so the
        # shortcut shows in the menu, but the key combo doesn't actually
        # fire the action yet. That needs WV2-child-HWND subclassing or a
        # WV2 shard hook on `AcceleratorKeyPressed` — tracked in ROADMAP.
        def self.set_from_options(handle : Void*, opts : Options::Menu, app_name : String) : Nil
          return if handle.null?

          # Tear down any previous menu attached by us.
          if prev = @@current_menus[handle]?
            LibUser32Menu.set_menu(handle, Pointer(Void).null)
            LibUser32Menu.destroy_menu(prev)
            @@current_menus.delete(handle)
            Lune::Native::Window.clear_command_handlers(handle)
          end

          registry = collect_registry(opts.top_level)
          return if opts.top_level.empty?

          hmenu = LibUser32Menu.create_menu
          return if hmenu.null?

          cmd_id_ref = Pointer(UInt32).malloc(1)
          cmd_id_ref.value = 1_u32

          opts.top_level.each do |item|
            case item.kind
            when Options::Menu::Item::Kind::Submenu
              sub = build_submenu(handle, item.children, registry, cmd_id_ref)
              next if sub.null?
              LibUser32Menu.append_menu_w(hmenu,
                LibUser32Menu::MF_STRING | LibUser32Menu::MF_POPUP,
                LibC::ULong.new(sub.address),
                wstr(item.label))
            when Options::Menu::Item::Kind::RoleApp, Options::Menu::Item::Kind::RoleEdit
              # No Win32 analogue — skip silently.
            else
              # Top-level clickables are unusual on Win32 menu bars; treat
              # them as flat menu-bar items anyway so the API still works.
              flags = LibUser32Menu::MF_STRING
              flags |= LibUser32Menu::MF_GRAYED unless item.enabled
              cmd = cmd_id_ref.value
              cmd_id_ref.value = cmd_id_ref.value + 1_u32
              register_handler(handle, cmd, item, registry)
              LibUser32Menu.append_menu_w(hmenu, flags, LibC::ULong.new(cmd),
                wstr(format_label(item)))
            end
          end

          @@current_menus[handle] = hmenu
          LibUser32Menu.set_menu(handle, hmenu)
          LibUser32Menu.draw_menu_bar(handle)
          nil
        end

        private def self.build_submenu(handle : Void*, items : Array(Options::Menu::Item),
                                       registry : Hash(String, Options::Menu::Item),
                                       cmd_id_ref : Pointer(UInt32)) : Void*
          popup = LibUser32Menu.create_popup_menu
          return popup if popup.null?

          items.each do |item|
            case item.kind
            when Options::Menu::Item::Kind::Separator
              LibUser32Menu.append_menu_w(popup, LibUser32Menu::MF_SEPARATOR,
                0_u64, Pointer(UInt16).null)
            when Options::Menu::Item::Kind::Submenu
              sub = build_submenu(handle, item.children, registry, cmd_id_ref)
              next if sub.null?
              LibUser32Menu.append_menu_w(popup,
                LibUser32Menu::MF_STRING | LibUser32Menu::MF_POPUP,
                LibC::ULong.new(sub.address),
                wstr(item.label))
            when Options::Menu::Item::Kind::RoleApp, Options::Menu::Item::Kind::RoleEdit
              # macOS-only
            else
              flags = LibUser32Menu::MF_STRING
              flags |= LibUser32Menu::MF_GRAYED unless item.enabled
              flags |= LibUser32Menu::MF_CHECKED if (item.kind.checkbox? || item.kind.radio?) && item.checked
              cmd = cmd_id_ref.value
              cmd_id_ref.value = cmd_id_ref.value + 1_u32
              register_handler(handle, cmd, item, registry)
              LibUser32Menu.append_menu_w(popup, flags, LibC::ULong.new(cmd),
                wstr(format_label(item)))
            end
          end

          popup
        end

        # Wires the per-item callback. Checkbox/radio items toggle their
        # `checked` state on Crystal side and re-render via CheckMenuItem on
        # the next round-trip; for now we just flip the field and fire the
        # callback — `app.update_menu` would rebuild the HMENU.
        private def self.register_handler(handle : Void*, cmd : UInt32,
                                          item : Options::Menu::Item,
                                          registry : Hash(String, Options::Menu::Item)) : Nil
          captured_item = item
          Lune::Native::Window.register_command_handler(handle, cmd) do
            case captured_item.kind
            when Options::Menu::Item::Kind::Checkbox
              captured_item.checked = !captured_item.checked
              captured_item.checked_callback.try(&.call(captured_item.checked))
            when Options::Menu::Item::Kind::Radio
              captured_item.checked = true
              captured_item.callback.try(&.call)
            else
              captured_item.callback.try(&.call)
            end
            nil
          end
        end

        # Renders the menu label with the shortcut hint appended after a tab,
        # which the Win32 menu draws right-aligned. Shortcut is darwin-style
        # (`"cmd+p"`) — translate to Win32 names so users see "Ctrl+P".
        private def self.format_label(item : Options::Menu::Item) : String
          shortcut = item.shortcut
          return item.label if shortcut.nil? || shortcut.empty?
          "#{item.label}\t#{translate_shortcut(shortcut)}"
        end

        private def self.translate_shortcut(s : String) : String
          parts = s.split('+').map do |raw|
            case raw.downcase
            when "cmd", "ctrl" then "Ctrl"
            when "alt", "opt"  then "Alt"
            when "shift"       then "Shift"
            when "meta", "win" then "Win"
            else
              raw.size == 1 ? raw.upcase : raw.capitalize
            end
          end
          parts.join('+')
        end

        private def self.wstr(s : String) : UInt16*
          arr = s.to_utf16
          buf = Pointer(UInt16).malloc(arr.size + 1)
          arr.size.times { |i| buf[i] = arr[i] }
          buf[arr.size] = 0_u16
          buf
        end

        private def self.collect_registry(items : Array(Options::Menu::Item)) : Hash(String, Options::Menu::Item)
          hash = {} of String => Options::Menu::Item
          items.each { |item| collect_into(hash, item) }
          hash
        end

        private def self.collect_into(hash : Hash(String, Options::Menu::Item), item : Options::Menu::Item)
          case item.kind
          when Options::Menu::Item::Kind::Text,
               Options::Menu::Item::Kind::Checkbox,
               Options::Menu::Item::Kind::Radio
            hash[item.id] = item
          when Options::Menu::Item::Kind::Submenu
            item.children.each { |c| collect_into(hash, c) }
          end
        end

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
