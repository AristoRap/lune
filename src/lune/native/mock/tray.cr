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

      module Tray
        def self.show(icon_path : String = "", on_click : (-> Nil)? = nil)
          TrayMock.record_show(icon_path, on_click)
        end

        def self.hide
          TrayMock.record_hide
        end

        def self.set_icon(icon_path : String)
          TrayMock.record_set_icon(icon_path)
        end

        def self.button_screen_rect : {Int32, Int32, Int32, Int32}?
          TrayMock.mock_button_rect
        end

        def self.set_right_click_cb(cb : (-> Nil)?)
          # no-op in tests
        end

        def self.popup_menu : Nil
          TrayMock.record_popup_menu
        end

        def self.set_menu(items : Array({id: String, label: String}), on_menu_click : (String -> Nil)? = nil)
          @@has_menu = items.any?
          TrayMock.record_set_menu(items, on_menu_click)
        end
      end
    end
  end
{% end %}
