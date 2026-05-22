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
            app.events.emit("window_closed", {"id" => id})
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
          app.events.emit("window_closed", {"id" => id})
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
