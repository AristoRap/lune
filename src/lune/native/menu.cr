require "json"

module Lune
  module Native
    # Public surface assembled in sibling files:
    #   - mock/menu.cr     MenuMock + Menu delegates (test mode)
    #   - darwin/menu.cr   LibNativeMenu (.m shim — app menu + context menu)
    #   - linux/menu.cr    No native menu yet — methods no-op
    #   - win32/menu.cr    LibUser32Menu (TrackPopupMenu); set_*/setup no-op
    #
    # Shared serialization + a tiny re-apply helper live here; each per-OS
    # file owns its own setup_default / set_from_options / show_context_menu.
    module Menu
      @@app_name : String = ""

      # Re-applies the menu after mutating Item properties (enabled, checked, label).
      def self.update(opts : Options::Menu)
        set_from_options(opts, @@app_name)
      end

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
                     else                                          item.kind.to_s.downcase
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
            json.field "id", item.id
            json.field "label", item.label
            json.field "enabled", item.enabled
            json.field "checked", item.checked
            if sc = item.shortcut
              parsed = Options::Menu::Shortcut.parse(sc)
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
