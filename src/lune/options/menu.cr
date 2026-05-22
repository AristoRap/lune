require "json"
require "uuid"

module Lune
  class Options
    # Application menu bar configuration, built via `opts.menu { |m| }`.
    #
    # ```
    # Lune.run(app) do |opts|
    #   opts.menu do |m|
    #     m.app_menu
    #     m.submenu "File" do |file|
    #       file.item("New", shortcut: "cmd+n") { }
    #       file.separator
    #       file.item("Quit", shortcut: "cmd+q") { app.quit }
    #     end
    #     m.edit_menu
    #   end
    # end
    # ```
    class Menu
      # A single item in a menu or submenu.
      #
      # Obtained by calling builder methods on `Group` or `Menu` —
      # keep the returned reference to mutate `enabled`, `checked`, or `label`
      # before calling `app.update_menu`.
      class Item
        enum Kind
          Text
          Separator
          Checkbox
          Radio
          Submenu
          RoleApp   # macOS standard application menu (About, Services, Hide, Quit)
          RoleEdit  # macOS standard edit menu (Undo, Redo, Cut, Copy, Paste, Select All)
        end

        getter id : String
        property label : String
        property kind : Kind
        property shortcut : String?
        property enabled : Bool
        property checked : Bool
        getter children : Array(Item)
        getter callback : (-> Nil)?
        getter checked_callback : (Bool -> Nil)?

        def initialize(
          @label : String = "",
          @kind : Kind = Kind::Text,
          @shortcut : String? = nil,
          @enabled : Bool = true,
          @checked : Bool = false,
          @children : Array(Item) = [] of Item,
          @callback : (-> Nil)? = nil,
          @checked_callback : (Bool -> Nil)? = nil
        )
          @id = UUID.random.to_s
        end
      end

      # Builder for the items inside one top-level menu (e.g. "File", "View").
      # Obtained by yielding from `Menu#submenu`.
      class Group
        getter label : String
        getter items : Array(Item)

        def initialize(@label : String)
          @items = [] of Item
        end

        # Adds a clickable text item. Returns the `Item` so you can hold a
        # reference for later mutation (e.g. toggling `enabled`).
        def item(label : String, shortcut : String? = nil, enabled : Bool = true, &cb : -> Nil) : Item
          m = Item.new(label: label, shortcut: shortcut, enabled: enabled, callback: cb)
          @items << m
          m
        end

        def separator : Item
          m = Item.new(kind: Item::Kind::Separator)
          @items << m
          m
        end

        # Adds a checkbox item. The block receives the new `Bool` checked state.
        def checkbox(label : String, checked : Bool = false, shortcut : String? = nil, &cb : Bool -> Nil) : Item
          m = Item.new(
            label: label, kind: Item::Kind::Checkbox,
            checked: checked, shortcut: shortcut, checked_callback: cb
          )
          @items << m
          m
        end

        # Adds a radio item. Adjacent radio items form a group automatically.
        # The block fires when this item is selected.
        def radio(label : String, selected : Bool = false, shortcut : String? = nil, &cb : -> Nil) : Item
          m = Item.new(
            label: label, kind: Item::Kind::Radio,
            checked: selected, shortcut: shortcut, callback: cb
          )
          @items << m
          m
        end

        # Adds a nested submenu via block. Returns the parent `Item` (kind Submenu).
        def submenu(label : String, &block : Group ->) : Item
          g = Group.new(label)
          yield g
          m = Item.new(label: label, kind: Item::Kind::Submenu, children: g.items)
          @items << m
          m
        end

        # Adds a pre-built `Group` subclass as a nested submenu.
        def submenu(group : Group) : Item
          m = Item.new(label: group.label, kind: Item::Kind::Submenu, children: group.items)
          @items << m
          m
        end
      end

      getter top_level : Array(Item)

      def initialize
        @top_level = [] of Item
      end

      # Inserts the standard macOS application menu (About, Services, Hide, Quit).
      # Should be the first item per macOS convention.
      def app_menu : Item
        m = Item.new(kind: Item::Kind::RoleApp)
        @top_level << m
        m
      end

      # Inserts the standard macOS edit menu (Undo, Redo, Cut, Copy, Paste, Select All).
      def edit_menu : Item
        m = Item.new(kind: Item::Kind::RoleEdit)
        @top_level << m
        m
      end

      # Adds a top-level submenu via block. Returns the `Item` (kind Submenu).
      def submenu(label : String, &block : Group ->) : Item
        g = Group.new(label)
        yield g
        m = Item.new(label: label, kind: Item::Kind::Submenu, children: g.items)
        @top_level << m
        m
      end

      # Adds a pre-built `Group` subclass as a top-level submenu.
      def submenu(group : Group) : Item
        m = Item.new(label: group.label, kind: Item::Kind::Submenu, children: group.items)
        @top_level << m
        m
      end

      def any? : Bool
        !@top_level.empty?
      end

      # Serializes the menu tree into the JSON shape consumed by the native
      # shims (macOS NSMenu builder, Win32 menu builder, mock test recorder).
      # Output: an array of top-level item objects; each item carries `kind`,
      # plus per-kind fields (`label`/`children` for submenus, `id`/`label`/
      # `enabled`/`checked`/`key`/`modifiers` for clickable items).
      def to_json : String
        JSON.build do |json|
          json.array do
            @top_level.each { |item| Menu.serialize_item(json, item) }
          end
        end
      end

      protected def self.serialize_item(json : JSON::Builder, item : Item)
        json.object do
          kind_str = case item.kind
                     when Item::Kind::RoleApp  then "role_app"
                     when Item::Kind::RoleEdit then "role_edit"
                     else                           item.kind.to_s.downcase
                     end
          json.field "kind", kind_str

          case item.kind
          when Item::Kind::Separator, Item::Kind::RoleApp, Item::Kind::RoleEdit
            # no additional fields
          when Item::Kind::Submenu
            json.field "label", item.label
            json.field "children" do
              json.array { item.children.each { |c| serialize_item(json, c) } }
            end
          else
            json.field "id", item.id
            json.field "label", item.label
            json.field "enabled", item.enabled
            json.field "checked", item.checked
            if sc = item.shortcut
              parsed = Shortcut.parse(sc)
              json.field "key", parsed.key
              json.field "modifiers", parsed.modifiers
            else
              json.field "key", ""
              json.field "modifiers", 0
            end
          end
        end
      end
    end
  end
end
