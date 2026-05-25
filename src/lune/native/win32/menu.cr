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

        # ACCEL.fVirt flags — see MSDN ACCEL struct.
        FVIRTKEY  = 0x01_u8
        FSHIFT    = 0x04_u8
        FCONTROL  = 0x08_u8
        FALT      = 0x10_u8

        struct Point
          x : LibC::Long
          y : LibC::Long
        end

        # Layout matches Win32 ACCEL (1-byte fVirt + 1-byte pad + 2-byte key
        # + 2-byte cmd = 6 bytes). Crystal's default struct alignment gives
        # us the padding for free.
        struct Accel
          f_virt : UInt8
          key : UInt16
          cmd : UInt16
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
        fun create_accelerator_table_w = CreateAcceleratorTableW(accel : Accel*, count : LibC::Int) : Void*
        fun destroy_accelerator_table = DestroyAcceleratorTable(haccel : Void*) : LibC::Int
      end

      module Menu
        # Per-HWND HMENU we built and attached, kept alive so a follow-up
        # `set_from_options` (e.g. `app.update_menu`) can destroy the prior
        # tree before swapping in a new one. The HMENU is also reachable via
        # `GetMenu(hwnd)` but tracking it here avoids relying on the win32
        # call returning the exact pointer we built.
        @@current_menus = {} of Void* => Void*

        # Per-HWND HACCEL built from the same items. Runner pulls this via
        # `current_accel_for(handle)` and hands it to `wv.set_accel` so the
        # forked webview shard's run_impl runs TranslateAcceleratorW on it
        # before WV2 grabs the keystroke. Cleaned up on menu rebuild.
        @@current_accels = {} of Void* => Void*

        # Observers fired after every successful `set_from_options` so
        # consumers (the runner, mainly) can re-install the new HACCEL on
        # the webview. Required because `app.update_menu` rebuilds the
        # menu — and destroys the prior HACCEL — at runtime; the wv's
        # `s_accel_table` would otherwise be left pointing at freed memory.
        # Argument is the new HACCEL (nil if the new menu has no shortcuts).
        @@menu_rebuild_observers = {} of Void* => Array(Proc(Void*?, Nil))

        # Subscribe to menu-rebuild events on `handle`. The block runs
        # synchronously after the new HMENU + HACCEL are attached, on
        # the same fiber that called `set_from_options`.
        def self.on_menu_rebuild(handle : Void*, &block : Void*? -> Nil) : Nil
          (@@menu_rebuild_observers[handle] ||= [] of Proc(Void*?, Nil)) << block
        end

        # Runner-facing getter — nil if no menu (or no shortcuts) on this HWND.
        def self.current_accel_for(handle : Void*) : Void*?
          @@current_accels[handle]?
        end

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
        # Accelerator strings (`"cmd+p"`) render as right-aligned hint text
        # after a `\t` separator (e.g. "Pause Clock\tCtrl+P"), but the key
        # combo doesn't actually fire the action: WV2 grabs the WM_KEYDOWN
        # at a layer below our parent WindowProc, and WH_KEYBOARD-based
        # interception was too unreliable in practice (worked initially,
        # broke after navigation, no clean way to suppress WV2's defaults
        # without its `AcceleratorKeyPressed` event — which the webview
        # shard doesn't expose yet). Tracked in ROADMAP.
        def self.set_from_options(handle : Void*, opts : Options::Menu, app_name : String) : Nil
          return if handle.null?

          # NOTE: do NOT detach the old menu yet — calling SetMenu(NULL)
          # before re-attaching causes the non-client area to resize
          # twice (no menu → with menu), which the main window shows
          # as visible jitter on every `app.update_menu` call. Build
          # the new HMENU first, swap atomically via a single SetMenu,
          # then destroy the old.
          prev_menu = @@current_menus[handle]?
          prev_accel = @@current_accels[handle]?
          Lune::Native::Window.clear_command_handlers(handle) if prev_menu

          registry = collect_registry(opts.top_level)
          return if opts.top_level.empty?

          hmenu = LibUser32Menu.create_menu
          return if hmenu.null?

          cmd_id_ref = Pointer(UInt32).malloc(1)
          cmd_id_ref.value = 1_u32
          accels = [] of LibUser32Menu::Accel

          opts.top_level.each do |item|
            case item.kind
            when Options::Menu::Item::Kind::Submenu
              sub = build_submenu(handle, item.children, registry, cmd_id_ref, accels)
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
              if accel = build_accel_entry(item.shortcut, cmd)
                accels << accel
              end
              LibUser32Menu.append_menu_w(hmenu, flags, LibC::ULong.new(cmd),
                wstr(format_label(item)))
            end
          end

          # Atomic swap: SetMenu replaces the menu in one step so the
          # non-client area only resizes once (no transient NULL-menu
          # state that would cause the visible jitter we'd get from
          # SetMenu(NULL) → SetMenu(hmenu)). DrawMenuBar redraws once.
          @@current_menus[handle] = hmenu
          LibUser32Menu.set_menu(handle, hmenu)
          LibUser32Menu.draw_menu_bar(handle)
          LibUser32Menu.destroy_menu(prev_menu) if prev_menu

          unless accels.empty?
            haccel = LibUser32Menu.create_accelerator_table_w(accels.to_unsafe, accels.size)
            if haccel.null?
              ::Lune.logger.error { "Win32 menu: CreateAcceleratorTableW returned NULL" }
            else
              @@current_accels[handle] = haccel
            end
          end
          @@current_accels.delete(handle) if accels.empty? && prev_accel

          # Notify observers (the runner + every open child window) so
          # they refresh `wv.set_accel` BEFORE we destroy the old HACCEL
          # — otherwise the wv's s_accel_table would briefly dangle.
          if observers = @@menu_rebuild_observers[handle]?
            new_accel = @@current_accels[handle]?
            observers.each(&.call(new_accel))
          end
          LibUser32Menu.destroy_accelerator_table(prev_accel) if prev_accel
          nil
        end

        private def self.build_submenu(handle : Void*, items : Array(Options::Menu::Item),
                                       registry : Hash(String, Options::Menu::Item),
                                       cmd_id_ref : Pointer(UInt32),
                                       accels : Array(LibUser32Menu::Accel)) : Void*
          popup = LibUser32Menu.create_popup_menu
          return popup if popup.null?

          items.each do |item|
            case item.kind
            when Options::Menu::Item::Kind::Separator
              LibUser32Menu.append_menu_w(popup, LibUser32Menu::MF_SEPARATOR,
                0_u64, Pointer(UInt16).null)
            when Options::Menu::Item::Kind::Submenu
              sub = build_submenu(handle, item.children, registry, cmd_id_ref, accels)
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
              if accel = build_accel_entry(item.shortcut, cmd)
                accels << accel
              end
              LibUser32Menu.append_menu_w(popup, flags, LibC::ULong.new(cmd),
                wstr(format_label(item)))
            end
          end

          popup
        end

        # Parse a darwin-style shortcut ("cmd+shift+p") into an ACCEL entry
        # for CreateAcceleratorTableW. Returns nil if the shortcut is empty
        # or the key isn't recognized (in which case the menu still shows
        # the hint text but the keystroke won't fire — caller decides).
        # Supports A-Z, 0-9, F1-F12, and these specials: enter, esc/escape,
        # tab, space, backspace, delete, up/down/left/right.
        private def self.build_accel_entry(shortcut : String?, cmd : UInt32) : LibUser32Menu::Accel?
          return nil if shortcut.nil? || shortcut.empty?
          parts = shortcut.split('+').map(&.downcase.strip)
          return nil if parts.empty?

          f_virt = LibUser32Menu::FVIRTKEY
          key_part = parts.last
          parts[0..-2].each do |mod|
            case mod
            when "cmd", "ctrl"  then f_virt |= LibUser32Menu::FCONTROL
            when "alt", "opt"   then f_virt |= LibUser32Menu::FALT
            when "shift"        then f_virt |= LibUser32Menu::FSHIFT
            when "meta", "win"  then return nil # no FWIN flag — Windows key isn't routable via accel
            else                     return nil
            end
          end

          vk = vk_code(key_part)
          return nil if vk.nil?

          a = LibUser32Menu::Accel.new
          a.f_virt = f_virt
          a.key = vk
          a.cmd = cmd.to_u16
          a
        end

        private def self.vk_code(key : String) : UInt16?
          return nil if key.empty?

          # Single letter: VK_A..VK_Z == 0x41..0x5A == ASCII uppercase.
          if key.size == 1
            ch = key[0]
            if ch.ascii_letter?
              return ch.upcase.ord.to_u16
            end
            if ch.ascii_number?
              return ch.ord.to_u16 # VK_0..VK_9 == 0x30..0x39
            end
          end

          # F1..F24
          if key.starts_with?("f") && key.size <= 3
            if n = key[1..].to_i?
              return (0x70_u16 + (n - 1).to_u16) if n >= 1 && n <= 24
            end
          end

          case key
          when "enter", "return"      then 0x0D_u16 # VK_RETURN
          when "esc", "escape"        then 0x1B_u16 # VK_ESCAPE
          when "tab"                  then 0x09_u16 # VK_TAB
          when "space"                then 0x20_u16 # VK_SPACE
          when "backspace"            then 0x08_u16 # VK_BACK
          when "delete", "del"        then 0x2E_u16 # VK_DELETE
          when "up"                   then 0x26_u16 # VK_UP
          when "down"                 then 0x28_u16 # VK_DOWN
          when "left"                 then 0x25_u16 # VK_LEFT
          when "right"                then 0x27_u16 # VK_RIGHT
          else nil
          end
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
        # The keystroke itself dispatches via the HACCEL built in
        # `set_from_options` and installed on the wv's message pump
        # (`TranslateAcceleratorW` + `AcceleratorKeyPressed` event in the
        # forked webview shard).
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
