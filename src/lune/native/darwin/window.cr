{% if flag?(:darwin) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/macos' && clang -c window.m -o window.o -fobjc-arc 2>/dev/null") %}

  module Lune
    module Native
      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/macos/window.o")]
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
        fun set_titlebar_transparent(window : Void*, full_size_content : LibC::Int) : Void
        fun set_background_transparent(window : Void*) : Void
        fun setup_drag_monitor : Void
        fun start_window_drag(window : Void*) : Void
        fun hide_title(window : Void*) : Void
        fun hide_traffic_lights(window : Void*) : Void
        fun set_appearance(window : Void*, mode : LibC::Int) : Void
        fun set_content_protection(window : Void*, enabled : LibC::Int) : Void
        fun set_always_on_top(window : Void*, enabled : LibC::Int) : Void
        alias DropCallback = (LibC::Char*, Void*) -> Void
        fun disable_webview_drop(window : Void*) : Void
        # drag_pos_fn / drop_check_fn: JS function names, e.g.
        # "window.__lune.dragPos" / "window.__lune.dropCheck", or NULL.
        # When drop_check_fn is set, performDragOperation evaluates it
        # directly via evaluateJavaScript: instead of routing through
        # Crystal's wv.dispatch — keeps the drop event out of the queue
        # behind pending dragPos updates.
        fun setup_file_drop(window : Void*,
                            drop_cb : DropCallback, drop_ud : Void*,
                            drag_pos_fn : LibC::Char*,
                            drop_check_fn : LibC::Char*) : Void
        fun lune_start_drag_out(window : Void*, paths_json : LibC::Char*) : Void
        fun lune_window_close(window : Void*) : Void
        alias CloseCallback = Void* ->
        fun lune_window_observe_close(window : Void*, cb : CloseCallback, arg : Void*) : Void
        fun lune_set_activation_policy_accessory : Void
        fun lune_hide_window(window : Void*) : Void
        fun lune_show_window(window : Void*) : Void
        fun lune_is_window_visible(window : Void*) : LibC::Int
        fun lune_window_auto_hide_on_resign_key(window : Void*) : Void
      end

      module Window
        # Pinned per window handle so multiple windows can have live drop /
        # close callbacks without overwriting each other's GC anchors.
        @@drop_boxes = {} of Void* => Pointer(Void)
        @@close_procs = {} of Void* => Proc(Nil)

        def self.disable_webview_drop(handle : Void*)
          LibNativeWindow.disable_webview_drop(handle)
        end

        # on_drop       receives (x, y, paths) — coordinates in CSS pixels (origin top-left)
        # on_pos        receives (x, y) on each drag-move (unused on macOS — drag_pos_fn handles it)
        # drag_pos_fn   JS function name called natively on macOS, e.g. "window.__lune.dragPos"
        # drop_check_fn JS function name called natively on macOS on drop — fires synchronously
        #               from performDragOperation so it doesn't queue behind dragPos evals.
        def self.setup_file_drop(handle : Void*,
                                 on_drop : (Int32, Int32, Array(String)) -> Nil,
                                 on_pos : (Int32, Int32) -> Nil,
                                 drag_pos_fn : String? = nil,
                                 drop_check_fn : String? = nil)
          @@drop_boxes[handle] = Box.box(on_drop)
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
            drag_pos_fn ? drag_pos_fn.to_unsafe : Pointer(LibC::Char).null,
            drop_check_fn ? drop_check_fn.to_unsafe : Pointer(LibC::Char).null
          )
        end

        def self.start_drag_out(handle : Void*, paths : Array(String))
          LibNativeWindow.lune_start_drag_out(handle, paths.to_json)
        end

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

        def self.set_titlebar_transparent(handle : Void*, full_size_content : Bool)
          LibNativeWindow.set_titlebar_transparent(handle, full_size_content ? 1 : 0)
        end

        def self.set_background_transparent(handle : Void*)
          LibNativeWindow.set_background_transparent(handle)
        end

        def self.setup_drag_monitor
          LibNativeWindow.setup_drag_monitor
        end

        def self.start_window_drag(handle : Void*)
          LibNativeWindow.start_window_drag(handle)
        end

        def self.hide_title(handle : Void*)
          LibNativeWindow.hide_title(handle)
        end

        def self.hide_traffic_lights(handle : Void*)
          LibNativeWindow.hide_traffic_lights(handle)
        end

        def self.set_appearance(handle : Void*, mode : Int32)
          LibNativeWindow.set_appearance(handle, mode)
        end

        def self.set_content_protection(handle : Void*, enabled : Bool)
          LibNativeWindow.set_content_protection(handle, enabled ? 1 : 0)
        end

        def self.set_always_on_top(handle : Void*, enabled : Bool)
          LibNativeWindow.set_always_on_top(handle, enabled ? 1 : 0)
        end

        def self.close(handle : Void*)
          LibNativeWindow.lune_window_close(handle)
        end

        def self.set_activation_policy_accessory
          LibNativeWindow.lune_set_activation_policy_accessory
        end

        def self.hide(handle : Void*)
          LibNativeWindow.lune_hide_window(handle)
        end

        def self.show(handle : Void*)
          LibNativeWindow.lune_show_window(handle)
        end

        def self.visible?(handle : Void*) : Bool
          LibNativeWindow.lune_is_window_visible(handle) != 0
        end

        def self.auto_hide_on_resign_key(handle : Void*)
          LibNativeWindow.lune_window_auto_hide_on_resign_key(handle)
        end

        # Registers a one-shot callback that fires on the main thread when the
        # NSWindow receives NSWindowWillCloseNotification (OS × button OR programmatic
        # close). The block is always called exactly once and then discarded.
        def self.on_close(handle : Void*, &block : ->) : Nil
          captured = block
          @@close_procs[handle] = captured
          LibNativeWindow.lune_window_observe_close(handle, ->(arg : Void*) {
            if cb = @@close_procs[arg]?
              @@close_procs.delete(arg)
              cb.call
            end
          }, handle)
        end
      end
    end
  end
{% end %}
