require "json"

module Lune
  module Native
    {% if flag?(:lune_native_test_mock) %}
      module MenuMock
        @@calls = [] of Symbol
        @@last_app_name : String? = nil
        @@last_menu_json : String? = nil
        @@last_context_json : String? = nil
        @@context_stub_id : String = ""

        class_getter calls, last_app_name, last_menu_json, last_context_json, context_stub_id

        def self.reset
          @@calls.clear
          @@last_app_name = nil
          @@last_menu_json = nil
          @@last_context_json = nil
          @@context_stub_id = ""
        end

        def self.stub_context_selection(id : String)
          @@context_stub_id = id
        end

        def self.record_setup_default(app_name : String)
          @@calls << :setup_default
          @@last_app_name = app_name
        end

        def self.record_set_menu(app_name : String, json : String)
          @@calls << :set_menu
          @@last_app_name = app_name
          @@last_menu_json = json
        end

        def self.record_show_context_menu(x : Float32, y : Float32, json : String, &on_select : String -> Nil)
          @@calls << :show_context_menu
          @@last_context_json = json
          on_select.call(@@context_stub_id) unless @@context_stub_id.empty?
        end
      end
    {% elsif flag?(:darwin) %}
      {% system("cd '#{__DIR__}/../../../ext/native/macos' && clang -c menu.m -o menu.o -fobjc-arc 2>/dev/null") %}

      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../ext/native/macos/menu.o")]
      lib LibNativeMenu
        fun setup_default_menu(app_name : LibC::Char*) : Void
        fun lune_set_menu(
          app_name : LibC::Char*,
          json     : LibC::Char*,
          cb       : (LibC::Char*, Void*) ->,
          ctx      : Void*
        ) : Void
        fun lune_show_context_menu(
          window : Void*,
          x      : LibC::Float,
          y      : LibC::Float,
          json   : LibC::Char*,
          cb     : (LibC::Char*, Void*) ->,
          ctx    : Void*
        ) : Void
      end
    {% elsif flag?(:win32) %}
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
    {% end %}

    module Menu
      @@app_name : String = ""
      @@box : Void*? = nil
      @@ctx_box : Void*? = nil

      def self.setup_default(app_name : String)
        {% if flag?(:lune_native_test_mock) %}
          MenuMock.record_setup_default(app_name)
        {% elsif flag?(:darwin) %}
          LibNativeMenu.setup_default_menu(app_name)
        {% end %}
      end

      def self.set_from_options(opts : Options::Menu, app_name : String)
        @@app_name = app_name
        json = serialize(opts)
        {% if flag?(:lune_native_test_mock) %}
          MenuMock.record_set_menu(app_name, json)
        {% elsif flag?(:darwin) %}
          registry = collect_registry(opts.top_level)
          @@box = Box.box(registry)
          LibNativeMenu.lune_set_menu(
            app_name,
            json,
            ->(payload : LibC::Char*, ctx : Void*) {
              reg = Box(Hash(String, Options::Menu::Item)).unbox(ctx)
              dispatch(reg, String.new(payload))
            },
            @@box.not_nil!
          )
        {% end %}
      end

      # Re-applies the menu after mutating Item properties (enabled, checked, label).
      def self.update(opts : Options::Menu)
        set_from_options(opts, @@app_name)
      end

      # Shows a native context menu at (x, y) in web coordinates and yields the
      # selected item's id. The block is not called if the menu is dismissed.
      def self.show_context_menu(handle : Void*, x : Float32, y : Float32, items_json : String, &on_select : String -> Nil)
        cb = on_select
        {% if flag?(:lune_native_test_mock) %}
          MenuMock.record_show_context_menu(x, y, items_json) { |id| cb.call(id) }
        {% elsif flag?(:darwin) %}
          box = Box.box(cb)
          @@ctx_box = box
          LibNativeMenu.lune_show_context_menu(
            handle, x, y, items_json,
            ->(payload : LibC::Char*, ctx : Void*) {
              fn = Box(Proc(String, Nil)).unbox(ctx)
              data = JSON.parse(String.new(payload))
              id = data["id"]?.try(&.as_s) || ""
              fn.call(id) unless id.empty?
            },
            box
          )
        {% elsif flag?(:win32) %}
          # Parse the JSON shape used by Lune::Capabilities::ContextMenu —
          # an array of {id, label, enabled?} or {kind: "separator"}.
          # Build a popup menu, track it modally, and translate the result
          # back to the user's item id via a Crystal-side id→string map.
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
            id    = obj["id"]?.try(&.as_s) || next.to_s
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
          pt.x = x.to_i.to_long
          pt.y = y.to_i.to_long
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
        {% end %}
      end

      # ── Serialization ───────────────────────────────────────────────────────

      def self.serialize(opts : Options::Menu) : String
        JSON.build do |json|
          json.array do
            opts.top_level.each { |item| serialize_item(json, item) }
          end
        end
      end

      private def self.serialize_item(json : JSON::Builder, item : Options::Menu::Item)
        json.object do
          kind_str = case item.kind
                     when Options::Menu::Item::Kind::RoleApp  then "role_app"
                     when Options::Menu::Item::Kind::RoleEdit then "role_edit"
                     else item.kind.to_s.downcase
                     end
          json.field "kind", kind_str

          case item.kind
          when Options::Menu::Item::Kind::Separator, Options::Menu::Item::Kind::RoleApp, Options::Menu::Item::Kind::RoleEdit
            # no additional fields
          when Options::Menu::Item::Kind::Submenu
            json.field "label", item.label
            json.field "children" do
              json.array { item.children.each { |c| serialize_item(json, c) } }
            end
          else
            json.field "id",      item.id
            json.field "label",   item.label
            json.field "enabled", item.enabled
            json.field "checked", item.checked
            if sc = item.shortcut
              parsed = Options::Menu::Shortcut.parse(sc)
              json.field "key",       parsed.key
              json.field "modifiers", parsed.modifiers
            else
              json.field "key",       ""
              json.field "modifiers", 0
            end
          end
        end
      end

      # ── Callback dispatch ───────────────────────────────────────────────────

      private def self.collect_registry(items : Array(Options::Menu::Item)) : Hash(String, Options::Menu::Item)
        hash = {} of String => Options::Menu::Item
        items.each { |item| collect_into(hash, item) }
        hash
      end

      private def self.collect_into(hash : Hash(String, Options::Menu::Item), item : Options::Menu::Item)
        case item.kind
        when Options::Menu::Item::Kind::Text, Options::Menu::Item::Kind::Checkbox, Options::Menu::Item::Kind::Radio
          hash[item.id] = item
        when Options::Menu::Item::Kind::Submenu
          item.children.each { |c| collect_into(hash, c) }
        end
      end

      private def self.dispatch(registry : Hash(String, Options::Menu::Item), payload : String)
        data = JSON.parse(payload)
        id   = data["id"]?.try(&.as_s?) || return
        item = registry[id]? || return

        if item.kind.checkbox? || item.kind.radio?
          checked = data["checked"]?.try(&.as_bool?) || false
          item.checked = checked
          item.checked_callback.try(&.call(checked))
        else
          item.callback.try(&.call)
        end
      end
    end
  end
end
