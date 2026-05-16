require "json"

module Lune
  module Native
    {% if flag?(:lune_native_test_mock) %}
      module MenuMock
        @@calls = [] of Symbol
        @@last_app_name : String? = nil
        @@last_menu_json : String? = nil

        class_getter calls, last_app_name, last_menu_json

        def self.reset
          @@calls.clear
          @@last_app_name = nil
          @@last_menu_json = nil
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
      end
    {% end %}

    module Menu
      @@app_name : String = ""
      @@box : Void*? = nil

      def self.setup_default(app_name : String)
        {% if flag?(:lune_native_test_mock) %}
          MenuMock.record_setup_default(app_name)
        {% elsif flag?(:darwin) %}
          LibNativeMenu.setup_default_menu(app_name)
        {% end %}
      end

      def self.set_from_options(opts : MenuOptions, app_name : String)
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
              reg = Box(Hash(String, MenuItem)).unbox(ctx)
              dispatch(reg, String.new(payload))
            },
            @@box.not_nil!
          )
        {% end %}
      end

      # Re-applies the menu after mutating MenuItem properties (enabled, checked, label).
      def self.update(opts : MenuOptions)
        set_from_options(opts, @@app_name)
      end

      # ── Serialization ───────────────────────────────────────────────────────

      def self.serialize(opts : MenuOptions) : String
        JSON.build do |json|
          json.array do
            opts.top_level.each { |item| serialize_item(json, item) }
          end
        end
      end

      private def self.serialize_item(json : JSON::Builder, item : MenuItem)
        json.object do
          kind_str = case item.kind
                     when MenuItem::Kind::RoleApp  then "role_app"
                     when MenuItem::Kind::RoleEdit then "role_edit"
                     else item.kind.to_s.downcase
                     end
          json.field "kind", kind_str

          case item.kind
          when MenuItem::Kind::Separator, MenuItem::Kind::RoleApp, MenuItem::Kind::RoleEdit
            # no additional fields
          when MenuItem::Kind::Submenu
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
              parsed = MenuShortcut.parse(sc)
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

      private def self.collect_registry(items : Array(MenuItem)) : Hash(String, MenuItem)
        hash = {} of String => MenuItem
        items.each { |item| collect_into(hash, item) }
        hash
      end

      private def self.collect_into(hash : Hash(String, MenuItem), item : MenuItem)
        case item.kind
        when MenuItem::Kind::Text, MenuItem::Kind::Checkbox, MenuItem::Kind::Radio
          hash[item.id] = item
        when MenuItem::Kind::Submenu
          item.children.each { |c| collect_into(hash, c) }
        end
      end

      private def self.dispatch(registry : Hash(String, MenuItem), payload : String)
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
