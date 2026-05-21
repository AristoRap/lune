{% if flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      module WindowMock
        @@calls = [] of Symbol
        @@last_title : String? = nil
        @@last_size : Tuple(Int32, Int32)? = nil
        @@last_frame : Tuple(Int32, Int32, Int32, Int32)? = nil
        @@mock_frame : Tuple(Int32, Int32, Int32, Int32) = {0, 0, 1200, 800}
        @@last_full_size_content : Bool? = nil

        class_getter calls, last_title, last_size, last_frame, mock_frame, last_full_size_content

        def self.reset
          @@calls.clear
          @@last_title = nil
          @@last_size = nil
          @@last_frame = nil
          @@mock_frame = {0, 0, 1200, 800}
          @@last_full_size_content = nil
          @@last_appearance = nil
          @@last_drop_cb = nil
          @@last_drag_out_paths = nil
        end

        def self.mock_frame=(f : Tuple(Int32, Int32, Int32, Int32))
          @@mock_frame = f
        end

        def self.record_minimize
          @@calls << :minimize
        end

        def self.record_maximize
          @@calls << :maximize
        end

        def self.record_center
          @@calls << :center
        end

        def self.record_set_title(t : String)
          @@calls << :set_title; @@last_title = t
        end

        def self.record_set_size(w : Int32, h : Int32)
          @@calls << :set_size
          @@last_size = {w, h}
        end

        def self.record_set_frame(x : Int32, y : Int32, w : Int32, h : Int32)
          @@calls << :set_frame
          @@last_frame = {x, y, w, h}
        end

        @@last_appearance : Int32? = nil
        @@last_drop_cb : ((Int32, Int32, Array(String)) -> Nil)? = nil
        class_getter last_appearance, last_drop_cb

        def self.record_disable_webview_drop
          @@calls << :disable_webview_drop
        end

        def self.record_setup_file_drop(cb : (Int32, Int32, Array(String)) -> Nil)
          @@calls << :setup_file_drop
          @@last_drop_cb = cb
        end

        def self.simulate_drop(x : Int32, y : Int32, paths : Array(String))
          @@last_drop_cb.try(&.call(x, y, paths))
        end

        @@last_drag_out_paths : Array(String)? = nil
        class_getter last_drag_out_paths

        def self.record_start_drag_out(paths : Array(String))
          @@calls << :start_drag_out
          @@last_drag_out_paths = paths
        end

        def self.record_set_titlebar_transparent(full_size_content : Bool)
          @@calls << :set_titlebar_transparent
          @@last_full_size_content = full_size_content
        end

        def self.record_set_background_transparent
          @@calls << :set_background_transparent
        end

        def self.record_setup_drag_monitor
          @@calls << :setup_drag_monitor
        end

        def self.record_start_window_drag
          @@calls << :start_window_drag
        end

        def self.record_hide_title
          @@calls << :hide_title
        end

        def self.record_hide_traffic_lights
          @@calls << :hide_traffic_lights
        end

        def self.record_set_appearance(mode : Int32)
          @@calls << :set_appearance
          @@last_appearance = mode
        end

        def self.record_set_content_protection
          @@calls << :set_content_protection
        end

        def self.record_set_always_on_top
          @@calls << :set_always_on_top
        end

        @@last_visible : Bool = true
        class_getter last_visible

        def self.record_set_activation_policy_accessory
          @@calls << :set_activation_policy_accessory
        end

        def self.record_hide
          @@calls << :hide
          @@last_visible = false
        end

        def self.record_show
          @@calls << :show
          @@last_visible = true
        end

        def self.mock_visible=(v : Bool)
          @@last_visible = v
        end
      end
    end
  end
{% end %}
