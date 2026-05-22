{% if flag?(:darwin) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/macos' && clang -c tray.m -o tray.o -fobjc-arc 2>/dev/null") %}

  module Lune
    module Native
      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/macos/tray.o")]
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

      module Tray
        # Kept at class level so GC never collects boxed callbacks while the tray is live.
        @@box : Pointer(Void) = Pointer(Void).null
        @@menu_box : Pointer(Void) = Pointer(Void).null
        @@right_click_box : Pointer(Void) = Pointer(Void).null

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

        def self.button_screen_rect : {Int32, Int32, Int32, Int32}?
          r = LibNativeTray.lune_tray_button_screen_rect
          return nil if r.width == 0 && r.height == 0
          {r.x.to_i32, r.y.to_i32, r.width.to_i32, r.height.to_i32}
        end

        def self.set_right_click_cb(cb : (-> Nil)?)
          if cb
            @@right_click_box = Box.box(cb)
            LibNativeTray.lune_tray_set_right_click_cb(->(data : Void*) {
              return if data.null?
              Box(Proc(Nil)).unbox(data).call
            }, @@right_click_box)
          else
            LibNativeTray.lune_tray_set_right_click_cb(->(data : Void*) { }, Pointer(Void).null)
          end
        end

        def self.popup_menu : Nil
          LibNativeTray.tray_popup_menu
        end

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
