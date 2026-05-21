module Lune
  module Capabilities
    class Windows < Lune::Capability
      include Capability::BindPhase
      include Capability::Lifecycle
      include Capability::MainContextAware

      DESCRIPTOR = Descriptor.new(id: :windows, label: "Windows")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @windows = {} of String => Webview::Webview
      @bridges = {} of String => Bridge
      @main_wv : Webview::Webview? = nil
      @app : Lune::App? = nil
      @resolved : Capabilities::ResolvedSet? = nil
      @bindings_snapshot = [] of Binding

      def set_main_context(ctx : Capability::MainCtx) : Nil
        @main_wv = ctx.wv
        @app = ctx.app
        @resolved = ctx.resolved
        @bindings_snapshot = ctx.bindings
      end

      def install(ctx : BindCtx) : Nil
        ctx.define("open",
          args: ["Hash"],
          return_type: "String",
          async: true,
        ) do |raw|
          opts = raw[0]
          title = opts["title"]?.try(&.as_s) || "Window"
          url = opts["url"]?.try(&.as_s)
          width = opts["width"]?.try(&.as_i) || 800
          height = opts["height"]?.try(&.as_i) || 600

          main_wv = @main_wv.not_nil!
          app = @app.not_nil!
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
          JSON::Any.new(id)
        end

        ctx.define("close",
          args: ["String"],
          async: true,
        ) do |raw|
          id = raw[0].as_s
          wv2 = @windows[id]?
          bridge = @bridges[id]?

          if wv2 && bridge
            main_wv = @main_wv.not_nil!
            app = @app.not_nil!
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

          JSON::Any.new(nil)
        end

        ctx.define("list",
          return_type: "Array(String)",
          async: true,
        ) do |_raw|
          ids = @windows.keys.map { |k| JSON::Any.new(k) }
          JSON::Any.new(ids)
        end
      end

      def shutdown : Nil
        @bridges.each_value(&.close!)
        @windows.clear
        @bridges.clear
      end
    end
  end
end
