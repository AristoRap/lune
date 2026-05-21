{% if flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      module TrayMock
        @@calls : Array(Symbol) = [] of Symbol
        @@last_icon_path : String? = nil
        @@last_click_cb : (-> Nil)? = nil
        @@last_menu_items : Array({id: String, label: String})? = nil
        @@last_menu_cb : ((String -> Nil))? = nil

        class_getter calls, last_icon_path, last_click_cb, last_menu_items, last_menu_cb

        def self.reset
          @@calls.clear
          @@last_icon_path = nil
          @@last_click_cb = nil
          @@last_menu_items = nil
          @@last_menu_cb = nil
        end

        def self.record_show(icon_path : String, cb : (-> Nil)?)
          @@calls << :show
          @@last_icon_path = icon_path
          @@last_click_cb = cb
        end

        def self.simulate_click
          @@last_click_cb.try(&.call)
        end

        def self.record_set_menu(items : Array({id: String, label: String}), cb : ((String -> Nil))?)
          @@calls << :set_menu
          @@last_menu_items = items
          @@last_menu_cb = cb
        end

        def self.simulate_menu_click(id : String)
          @@last_menu_cb.try(&.call(id))
        end

        def self.record_hide
          @@calls << :hide
        end

        def self.record_set_icon(p : String)
          @@calls << :set_icon; @@last_icon_path = p
        end

        def self.record_popup_menu
          @@calls << :popup_menu
        end

        @@mock_button_rect : {Int32, Int32, Int32, Int32}? = nil
        class_getter mock_button_rect

        def self.mock_button_rect=(r : {Int32, Int32, Int32, Int32}?)
          @@mock_button_rect = r
        end
      end
    end
  end
{% end %}
