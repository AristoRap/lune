{% if flag?(:linux) && !flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      # Linux has no native menu implementation yet — all three entry points
      # silently no-op. (Capability layer is darwin- and win32-only today.)
      module Menu
        def self.setup_default(app_name : String); end

        def self.set_from_options(opts : Options::Menu, app_name : String)
          @@app_name = app_name
        end

        def self.show_context_menu(handle : Void*, x : Float32, y : Float32, items_json : String, &on_select : String -> Nil); end
      end
    end
  end
{% end %}
