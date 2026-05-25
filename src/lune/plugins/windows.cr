module Lune
  module Plugins
    class Windows < Lune::Plugin
      include Lune::Bindable
      include Plugin::Lifecycle
      include Plugin::MainContextAware

      DESCRIPTOR = Descriptor.new(id: :windows, label: "Windows")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @windows = {} of String => Webview::Webview
      @bridges = {} of String => Bridge
      @main_wv : Webview::Webview? = nil
      @resolved : Plugins::ResolvedSet? = nil
      @bindings_snapshot = [] of Binding

      def set_main_context(ctx : Plugin::MainCtx) : Nil
        @main_wv = ctx.wv
        @resolved = ctx.resolved
        @bindings_snapshot = ctx.bindings
      end

      @[Lune::Bind(async: true)]
      def open(opts : Hash(String, JSON::Any)) : String
        title = opts["title"]?.try(&.as_s) || "Window"
        url = opts["url"]?.try(&.as_s)
        width = opts["width"]?.try(&.as_i) || 800
        height = opts["height"]?.try(&.as_i) || 600

        main_wv = @main_wv.not_nil!
        app = @app
        bindings = @bindings_snapshot
        resolved = @resolved.not_nil!

        id = Random::Secure.hex(8)
        done = Channel(Nil).new(1)

        main_wv.dispatch do
          wv2 = Webview::Webview.new(false, title)
          wv2.size(width, height, Webview::SizeHints::NONE)
          handle = wv2.native_handle(Webview::NativeHandleKind::UI_WINDOW)

          {% if flag?(:win32) && !flag?(:lune_native_test_mock) %}
            # Route the child window's menu-accelerator hits back to the
            # main window's wndproc + command handlers, then install the
            # current HACCEL so the child wv's AcceleratorKeyPressed
            # handler has a table to match against. set_accel_target /
            # set_accel / set_browser_accelerator_keys_enabled are all
            # no-ops on non-Win32, so the macro guard is purely to avoid
            # the main_handle lookup on platforms that don't need it.
            main_handle = main_wv.native_handle(Webview::NativeHandleKind::UI_WINDOW)
            wv2.set_accel_target(main_handle)
            wv2.set_accel(Lune::Native::Menu.current_accel_for(main_handle))
            # Keep the child in sync on app.update_menu — old HACCEL is
            # destroyed by set_from_options and the new one needs to
            # reach every open child window. Guard on @windows so a
            # closed child's slot stops receiving updates.
            captured_id = id
            Lune::Native::Menu.on_menu_rebuild(main_handle) do |new_accel|
              wv2.set_accel(new_accel) if @windows[captured_id]?
            end
            wv2.set_browser_accelerator_keys_enabled(false)
          {% end %}

          resolved.init_all_webviews(wv2, handle, app)

          bridge = Bridge.new(wv2)
          bridge.register_bindings(bindings.reject(&.internal?))
          bridge.register_bindings(bindings.select(&.internal?))

          # NSWindowWillCloseNotification fires for both OS × and programmatic close.
          # For programmatic close the guard skips (maps already cleared by close binding);
          # for OS close it runs the full cleanup and emits window_closed to the main window.
          Native::Window.on_close(handle) do
            next if @windows[id]?.nil?
            bridge.close!
            @windows.delete(id)
            @bridges.delete(id)
            app.remove_bridge(bridge)
            app.event.emit("window_closed", {"id" => id})
          end

          wv2.navigate(url) if url

          @windows[id] = wv2
          @bridges[id] = bridge
          app.add_bridge(bridge)
          done.send(nil)
        end

        done.receive
        id
      end

      @[Lune::Bind(async: true)]
      def close(id : String) : Nil
        wv2 = @windows[id]?
        bridge = @bridges[id]?

        if wv2 && bridge
          main_wv = @main_wv.not_nil!
          app = @app
          handle = wv2.native_handle(Webview::NativeHandleKind::UI_WINDOW)
          done = Channel(Nil).new(1)

          main_wv.dispatch do
            bridge.close!
            @windows.delete(id)
            @bridges.delete(id)
            app.remove_bridge(bridge)
            Native::Window.close(handle)
            done.send(nil)
          end

          done.receive
          app.event.emit("window_closed", {"id" => id})
        end
      end

      @[Lune::Bind(async: true)]
      def list : Array(String)
        @windows.keys
      end

      def shutdown : Nil
        @bridges.each_value(&.close!)
        @windows.clear
        @bridges.clear
      end
    end
  end
end
