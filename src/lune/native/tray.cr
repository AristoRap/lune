module Lune
  module Native
    {% if flag?(:lune_native_test_mock) %}
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
    {% elsif flag?(:darwin) %}
      {% system("cd '#{__DIR__}/../../../ext/native/macos' && clang -c tray.m -o tray.o -fobjc-arc 2>/dev/null") %}

      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../ext/native/macos/tray.o")]
      lib LibNativeTray
        alias Callback     = (Void*) -> Void
        alias MenuCallback = (LibC::Char*, Void*) -> Void
        fun tray_show(icon_path : LibC::Char*, callback : Callback, userdata : Void*) : Void
        fun tray_hide : Void
        fun tray_set_icon(icon_path : LibC::Char*) : Void
        fun tray_set_menu(ids : LibC::Char**, labels : LibC::Char**, count : LibC::Int, callback : MenuCallback, userdata : Void*) : Void
        struct TrayRect
          x : LibC::Int
          y : LibC::Int
          width : LibC::Int
          height : LibC::Int
        end
        fun lune_tray_button_screen_rect : TrayRect
        fun lune_tray_set_right_click_cb(callback : Callback, userdata : Void*) : Void
        fun tray_popup_menu : Void
      end
    {% elsif flag?(:linux) %}
      {% system("cd '#{__DIR__}/../../../ext/native/linux' && gcc -c tray.c -o tray.o `pkg-config --cflags gtk+-3.0` 2>/dev/null") %}

      @[Link(ldflags: "#{__DIR__}/../../../ext/native/linux/tray.o")]
      @[Link(ldflags: "`pkg-config --libs gtk+-3.0`")]
      lib LibNativeTray
        alias Callback     = (Void*) -> Void
        alias MenuCallback = (LibC::Char*, Void*) -> Void
        fun tray_show(icon_path : LibC::Char*, callback : Callback, userdata : Void*) : Void
        fun tray_hide : Void
        fun tray_set_icon(icon_path : LibC::Char*) : Void
        fun tray_set_menu(ids : LibC::Char**, labels : LibC::Char**, count : LibC::Int, callback : MenuCallback, userdata : Void*) : Void
      end
    {% end %}

    module Tray
      # Kept at class level so GC never collects boxed callbacks while the tray is live.
      @@box : Pointer(Void) = Pointer(Void).null
      @@menu_box : Pointer(Void) = Pointer(Void).null
      @@right_click_box : Pointer(Void) = Pointer(Void).null

      # Crystal-side mirror of the current menu count. Lets capability defaults
      # decide between popping the menu and emitting an event at click time.
      @@has_menu : Bool = false

      def self.has_menu? : Bool
        @@has_menu
      end

      def self.show(icon_path : String = "", on_click : (-> Nil)? = nil)
        {% if flag?(:lune_native_test_mock) %}
          TrayMock.record_show(icon_path, on_click)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          if cb = on_click
            @@box = Box.box(cb)
            LibNativeTray.tray_show(icon_path, ->(data : Void*) {
              return if data.null?
              Box(Proc(Nil)).unbox(data).call
            }, @@box)
          else
            LibNativeTray.tray_show(icon_path, ->(data : Void*) { }, Pointer(Void).null)
          end
        {% end %}
      end

      def self.hide
        {% if flag?(:lune_native_test_mock) %}
          TrayMock.record_hide
        {% elsif flag?(:darwin) || flag?(:linux) %}
          LibNativeTray.tray_hide
        {% end %}
      end

      def self.set_icon(icon_path : String)
        {% if flag?(:lune_native_test_mock) %}
          TrayMock.record_set_icon(icon_path)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          LibNativeTray.tray_set_icon(icon_path)
        {% end %}
      end

      def self.button_screen_rect : {Int32, Int32, Int32, Int32}?
        {% if flag?(:lune_native_test_mock) %}
          TrayMock.mock_button_rect
        {% elsif flag?(:darwin) %}
          r = LibNativeTray.lune_tray_button_screen_rect
          return nil if r.width == 0 && r.height == 0
          {r.x.to_i32, r.y.to_i32, r.width.to_i32, r.height.to_i32}
        {% else %}
          nil
        {% end %}
      end

      def self.set_right_click_cb(cb : (-> Nil)?)
        {% if flag?(:lune_native_test_mock) %}
          # no-op in tests
        {% elsif flag?(:darwin) %}
          if cb
            @@right_click_box = Box.box(cb)
            LibNativeTray.lune_tray_set_right_click_cb(->(data : Void*) {
              return if data.null?
              Box(Proc(Nil)).unbox(data).call
            }, @@right_click_box)
          else
            LibNativeTray.lune_tray_set_right_click_cb(->(data : Void*) { }, Pointer(Void).null)
          end
        {% end %}
      end

      def self.popup_menu : Nil
        {% if flag?(:lune_native_test_mock) %}
          TrayMock.record_popup_menu
        {% elsif flag?(:darwin) %}
          LibNativeTray.tray_popup_menu
        {% end %}
      end

      def self.set_menu(items : Array({id: String, label: String}), on_menu_click : (String -> Nil)? = nil)
        @@has_menu = items.any?
        {% if flag?(:lune_native_test_mock) %}
          TrayMock.record_set_menu(items, on_menu_click)
        {% elsif flag?(:darwin) || flag?(:linux) %}
          ids = items.map { |i| i[:id].to_unsafe }
          labels = items.map { |i| i[:label].to_unsafe }
          if cb = on_menu_click
            @@menu_box = Box.box(cb)
            LibNativeTray.tray_set_menu(
              ids.to_unsafe, labels.to_unsafe, items.size,
              ->(id_ptr : LibC::Char*, data : Void*) {
                return if data.null?
                Box(Proc(String, Nil)).unbox(data).call(String.new(id_ptr))
              },
              @@menu_box
            )
          else
            LibNativeTray.tray_set_menu(
              ids.to_unsafe, labels.to_unsafe, items.size,
              ->(id_ptr : LibC::Char*, data : Void*) { },
              Pointer(Void).null
            )
          end
        {% end %}
      end
    end
  end
end
