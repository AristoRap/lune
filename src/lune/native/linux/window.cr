{% if flag?(:linux) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/linux' && gcc -c window.c -o window.o `pkg-config --cflags gtk+-3.0` 2>/dev/null") %}

  module Lune
    module Native
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/linux/window.o")]
      @[Link(ldflags: "`pkg-config --libs gtk+-3.0`")]
      lib LibNativeWindow
        struct Frame
          x : LibC::Int
          y : LibC::Int
          width : LibC::Int
          height : LibC::Int
        end
        fun minimize(window : Void*) : Void
        fun maximize(window : Void*) : Void
        fun set_title(window : Void*, title : LibC::Char*) : Void
        fun set_size(window : Void*, width : LibC::Int, height : LibC::Int) : Void
        fun center(window : Void*) : Void
        fun get_frame(window : Void*) : Frame
        fun set_frame(window : Void*, x : LibC::Int, y : LibC::Int, width : LibC::Int, height : LibC::Int) : Void
        alias DropCallback    = (LibC::Char*, Void*) -> Void
        alias DragPosCallback = (LibC::Int, LibC::Int, Void*) -> Void
        fun disable_webview_drop(window : Void*) : Void
        fun setup_file_drop(window : Void*,
                            drop_cb : DropCallback, drop_ud : Void*,
                            pos_cb : DragPosCallback, pos_ud : Void*) : Void
      end

      module Window
        # Pinned per window handle — Linux uses both drop + drag-position
        # boxed callbacks; GtkStatusIcon close events aren't wired (yet).
        @@drop_boxes = {} of Void* => Pointer(Void)
        @@drop_pos_boxes = {} of Void* => Pointer(Void)

        def self.disable_webview_drop(handle : Void*)
          LibNativeWindow.disable_webview_drop(handle)
        end

        def self.setup_file_drop(handle : Void*,
                                 on_drop : (Int32, Int32, Array(String)) -> Nil,
                                 on_pos : (Int32, Int32) -> Nil,
                                 drag_pos_fn : String? = nil,
                                 drop_check_fn : String? = nil)
          @@drop_boxes[handle] = Box.box(on_drop)
          @@drop_pos_boxes[handle] = Box.box(on_pos)
          LibNativeWindow.setup_file_drop(
            handle,
            ->(json_ptr : LibC::Char*, data : Void*) {
              return if data.null?
              begin
                parsed = JSON.parse(String.new(json_ptr))
                x = parsed["x"].as_i? || 0
                y = parsed["y"].as_i? || 0
                raw = parsed["paths"].as_a?
                paths = raw ? raw.compact_map(&.as_s?) : Array(String).new
                Box(Proc(Int32, Int32, Array(String), Nil)).unbox(data).call(x, y, paths)
              rescue JSON::ParseException | TypeCastError | KeyError
              end
            },
            @@drop_boxes[handle],
            ->(x : LibC::Int, y : LibC::Int, data : Void*) {
              return if data.null?
              Box(Proc(Int32, Int32, Nil)).unbox(data).call(x.to_i32, y.to_i32)
            },
            @@drop_pos_boxes[handle]
          )
        end

        # Darwin-only — Linux has no XDND-based outbound drag from Crystal yet.
        def self.start_drag_out(handle : Void*, paths : Array(String)); end

        def self.minimize(handle : Void*); LibNativeWindow.minimize(handle); end
        def self.maximize(handle : Void*); LibNativeWindow.maximize(handle); end
        def self.center(handle : Void*); LibNativeWindow.center(handle); end

        def self.set_title(handle : Void*, title : String)
          LibNativeWindow.set_title(handle, title)
        end

        def self.set_size(handle : Void*, width : Int32, height : Int32)
          LibNativeWindow.set_size(handle, width, height)
        end

        def self.get_frame(handle : Void*) : {Int32, Int32, Int32, Int32}
          f = LibNativeWindow.get_frame(handle)
          {f.x.to_i32, f.y.to_i32, f.width.to_i32, f.height.to_i32}
        end

        def self.alive?(handle : Void*) : Bool
          true
        end

        def self.set_frame(handle : Void*, x : Int32, y : Int32, width : Int32, height : Int32)
          LibNativeWindow.set_frame(handle, x, y, width, height)
        end

        # The remaining methods are darwin-specific (NSWindow / NSApplication
        # vocabulary); Linux silently does nothing to preserve a uniform API.
        def self.set_titlebar_transparent(handle : Void*, full_size_content : Bool); end
        def self.set_background_transparent(handle : Void*); end
        def self.setup_drag_monitor; end
        def self.start_window_drag(handle : Void*); end
        def self.hide_title(handle : Void*); end
        def self.hide_traffic_lights(handle : Void*); end
        def self.set_appearance(handle : Void*, mode : Int32); end
        def self.set_content_protection(handle : Void*, enabled : Bool); end
        def self.set_always_on_top(handle : Void*, enabled : Bool); end
        def self.close(handle : Void*); end
        def self.set_activation_policy_accessory; end
        def self.hide(handle : Void*); end
        def self.show(handle : Void*); end

        def self.visible?(handle : Void*) : Bool
          true
        end

        def self.auto_hide_on_resign_key(handle : Void*); end

        def self.on_close(handle : Void*, &block : ->) : Nil; end
      end
    end
  end
{% end %}
