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

        # Adds a nested submenu. Returns the parent `Item` (kind Submenu).
        def submenu(label : String, &block : Group ->) : Item
          g = Group.new(label)
          yield g
          m = Item.new(label: label, kind: Item::Kind::Submenu, children: g.items)
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

      # Adds a top-level submenu and yields its `Group` builder.
      # Returns the `Item` (kind Submenu) that was appended.
      def submenu(label : String, &block : Group ->) : Item
        g = Group.new(label)
        yield g
        m = Item.new(label: label, kind: Item::Kind::Submenu, children: g.items)
        @top_level << m
        m
      end

      def any? : Bool
        !@top_level.empty?
      end
    end
  end
end
