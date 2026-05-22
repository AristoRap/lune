{% if flag?(:linux) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/linux' && gcc -c tray.c -o tray.o `pkg-config --cflags gtk+-3.0` 2>/dev/null") %}

  module Lune
    module Native
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/linux/tray.o")]
      @[Link(ldflags: "`pkg-config --libs gtk+-3.0`")]
      lib LibNativeTray
        alias Callback     = (Void*) -> Void
        alias MenuCallback = (LibC::Char*, Void*) -> Void
        fun tray_show(icon_path : LibC::Char*, callback : Callback, userdata : Void*) : Void
        fun tray_hide : Void
        fun tray_set_icon(icon_path : LibC::Char*) : Void
        fun tray_set_menu(ids : LibC::Char**, labels : LibC::Char**, count : LibC::Int, callback : MenuCallback, userdata : Void*) : Void
      end

      module Tray
        @@box : Pointer(Void) = Pointer(Void).null
        @@menu_box : Pointer(Void) = Pointer(Void).null

        def self.show(icon_path : String = "", on_click : (-> Nil)? = nil)
          if cb = on_click
            @@box = Box.box(cb)
            LibNativeTray.tray_show(icon_path, ->(data : Void*) {
              return if data.null?
              Box(Proc(Nil)).unbox(data).call
            }, @@box)
          else
            LibNativeTray.tray_show(icon_path, ->(data : Void*) { }, Pointer(Void).null)
          end
        end

        def self.hide
          LibNativeTray.tray_hide
        end

        def self.set_icon(icon_path : String)
          LibNativeTray.tray_set_icon(icon_path)
        end

        # Linux GtkStatusIcon has no API to query the button's screen rect.
        def self.button_screen_rect : {Int32, Int32, Int32, Int32}?
          nil
        end

        # Linux GtkStatusIcon has no dedicated right-click callback — context
        # menu is wired via tray_set_menu directly.
        def self.set_right_click_cb(cb : (-> Nil)?); end

        # Linux: menu is owned by the GtkStatusIcon implementation; nothing
        # to do from Crystal-side.
        def self.popup_menu : Nil; end

        def self.set_menu(items : Array({id: String, label: String}), on_menu_click : (String -> Nil)? = nil)
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
        end
      end
    end
  end
{% end %}
