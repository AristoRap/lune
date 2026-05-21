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
    end
  end
{% end %}
