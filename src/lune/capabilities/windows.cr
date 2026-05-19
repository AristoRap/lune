module Lune
  module Capabilities
    class Windows < Lune::Capability
      include Capability::Bindable
      include Capability::Lifecycle

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

      def set_context(
        main_wv : Webview::Webview,
        app : Lune::App,
        resolved : Capabilities::ResolvedSet,
        bindings : Array(Binding),
      ) : Nil
        @main_wv = main_wv
        @app = app
        @resolved = resolved
        @bindings_snapshot = bindings
      end

      def install(ctx : BindCtx) : Nil
        ctx.register(Definition.new(
          name: "#{name}.open",
          args: ["Hash"],
          return_type: "String",
          async: true,
          ts_return_type: "Promise<string>",
          callback: ->(raw : Array(JSON::Any)) {
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

              inject_sentinels(wv2, resolved)

              bridge = Bridge.new(wv2)
              bridge.register_bindings(bindings.reject(&.internal?))
              bridge.register_bindings(bindings.select(&.internal?))

              handle = wv2.native_handle(Webview::NativeHandleKind::UI_WINDOW)

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
          },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.close",
          args: ["String"],
          return_type: "Nil",
          async: true,
          callback: ->(raw : Array(JSON::Any)) {
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
          },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.list",
          args: [] of String,
          return_type: "Array",
          async: true,
          ts_return_type: "Promise<string[]>",
          callback: ->(raw : Array(JSON::Any)) {
            ids = @windows.keys.map { |k| JSON::Any.new(k) }
            JSON::Any.new(ids)
          },
        ).binding(binding_namespace))
      end

      def shutdown : Nil
        @bridges.each_value(&.close!)
        @windows.clear
        @bridges.clear
      end

      private def inject_sentinels(wv : Webview::Webview, resolved : Capabilities::ResolvedSet) : Nil
        resolved.capabilities.each do |cap|
          wv.init("window[#{cap.sentinel_key.inspect}] = true;")
        end
        bm = Lune::Capability::BRIDGE_MARKER
        unless resolved.active_ids.includes?(:event_bus)
          js_emit_key = "#{bm}.jsEmit"
          wv.init("(function(){window.#{bm}=window.#{bm}||{};var n=function(){};window.#{bm}.crystalEmit=n;window.#{bm}.on=n;window.#{bm}.off=n;window[#{js_emit_key.inspect}]=function(){return Promise.resolve();};})();")
        end
        unless resolved.active_ids.includes?(:stream)
          wv.init("(function(){window.#{bm}=window.#{bm}||{};var n=function(){};window.#{bm}.stOn=n;window.#{bm}.stOff=n;window.#{bm}.stSend=n;})();")
        end
      end
    end
  end
end
