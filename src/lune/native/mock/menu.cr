{% if flag?(:lune_native_test_mock) %}
  module Lune
    module Native
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

      module Menu
        def self.setup_default(handle : Void*, app_name : String)
          MenuMock.record_setup_default(app_name)
        end

        def self.set_from_options(handle : Void*, opts : Options::Menu, app_name : String)
          MenuMock.record_set_menu(app_name, opts.to_json)
        end

        def self.show_context_menu(handle : Void*, x : Float32, y : Float32, items_json : String, &on_select : String -> Nil)
          cb = on_select
          MenuMock.record_show_context_menu(x, y, items_json) { |id| cb.call(id) }
        end
      end
    end
  end
{% end %}
