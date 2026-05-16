module Lune
  class Runner
    getter options : Options

    def initialize(app : App, &block : Options -> Nil)
      @app = app
      @lunejs_dir = File.join(ENV.fetch(Lune::ENV_FRONTEND_DIR, Lune::DEFAULT_FRONTEND_DIR), Lune::LUNEJS_SUBDIR)
      @config = Config.load
      @options = Options.new
      @options.apply(@config.window)
      block.call(@options)
    end

    def start(html : String? = nil, url : String? = nil)
      STDOUT.sync = true
      @options.hint = @options.resizable ? @options.hint : Webview::SizeHints::FIXED
      # Windows ONLY: run the webview on a separate thread
      {% if flag?(:win32) %}
        done = Channel(Exception?).new(1)
        Fiber::ExecutionContext::Isolated.new("webview") do
          webview(html, url)
          done.send(nil)
        rescue ex
          done.send(ex)
        end
        done.receive.try { |ex| raise ex }
      {% else %}
        webview(html, url)
      {% end %}
    end

    private def webview(html : String? = nil, url : String? = nil) : Nil
      Webview.with_window(@options.width, @options.height, @options.hint, @options.title, @options.debug) do |wv|
        wv.size(@options.min_width || 0, @options.min_height || 0, Webview::SizeHints::MIN) if @options.min_width || @options.min_height
        wv.size(@options.max_width || 0, @options.max_height || 0, Webview::SizeHints::MAX) if @options.max_width || @options.max_height
        bridge = Bridge.new(wv)
        bridge.register_bindings(@app.bindings)

        runtime_app = App.new
        runtime_app.install(
          Runtime::Bindings::Lifecycle.new(
            on_quit: -> { wv.dispatch { wv.terminate } },
            debug: @options.debug
          ),
          Runtime::Bindings::Filesystem.new,
          Runtime::Bindings::Clipboard.new
        )
        runtime_bindings = Runtime::Bindings.filter(runtime_app.bindings, @config.capabilities)
        bridge.register_bindings(runtime_bindings)
        @app.bridge = bridge

        handle = wv.native_handle(Webview::NativeHandleKind::UI_WINDOW)

        Native::Menu.setup_default(@options.title)

        mac = @options.mac
        {% if flag?(:darwin) %}
          Native::Window.set_titlebar_transparent(handle, true) if mac.full_size_content
          Native::Window.set_background_transparent(handle) if mac.transparent
          Native::Window.hide_title(handle) if mac.hide_title
          Native::Window.set_appearance(handle, mac.appearance.value) unless mac.appearance.auto?
          Native::Window.set_content_protection(handle, true) if mac.content_protection
          Native::Window.set_always_on_top(handle, true) if mac.always_on_top
        {% end %}

        native_app = App.new
        native_app.install(
          Runtime::Bindings::Window.new(handle),
          Runtime::Bindings::Tray.new(
            on_tray_click: @options.on_tray_click,
            on_menu_click: @options.on_menu_click
          ),
          Runtime::Bindings::Dialogs.new,
          Runtime::Bindings::Notifications.new,
          Runtime::Bindings::Screen.new
        )
        native_bindings = Runtime::Bindings.filter(native_app.bindings, @config.capabilities)
        bridge.register_bindings(native_bindings)

        {% if flag?(:darwin) %}
          unless @options.drag_zone.empty?
            Native::Window.setup_drag_monitor
            drag_handle = handle
            wv.bind("__lune_start_window_drag", Webview::JSProc.new { |_args|
              Native::Window.start_window_drag(drag_handle)
              JSON::Any.new(nil)
            })
          end
        {% end %}

        if window_ready_cb = @options.on_window_ready
          begin
            window_ready_cb.call(handle)
          rescue ex
            Lune.logger.error { "on_window_ready callback failed: #{ex.message}" }
            Lune.logger.debug(exception: ex) { "on_window_ready callback failed (stacktrace)" }
          end
        end

        window_app_name = WindowState.app_name(@options.title)
        if saved = WindowState.load(window_app_name)
          Native::Window.set_frame(handle, saved[:x], saved[:y], saved[:width], saved[:height])
        end

        should_drop = @options.enable_file_drop || @options.on_file_drop != nil

        if should_drop || @options.disable_webview_drop
          Native::Window.disable_webview_drop(handle)
        end

        if should_drop
          user_cb = @options.on_file_drop
          app_ref = @app
          use_drop_zones = !@options.drop_zone.empty?
          wv_ref = wv

          on_pos : (Int32, Int32) -> Nil = if use_drop_zones
            ->(x : Int32, y : Int32) {
              wv_ref.dispatch { wv_ref.eval("window.__lune_drag_pos(#{x},#{y})") }
            }
          else
            ->(x : Int32, y : Int32) { nil }
          end

          on_drop : (Int32, Int32, Array(String)) -> Nil = if use_drop_zones
            ->(x : Int32, y : Int32, paths : Array(String)) {
              user_cb.try(&.call(x, y, paths))
              paths_json = paths.to_json
              wv_ref.dispatch { wv_ref.eval("window.__lune_drop_check(#{x},#{y},#{paths_json.inspect})") }
            }
          else
            ->(x : Int32, y : Int32, paths : Array(String)) {
              user_cb.try(&.call(x, y, paths))
              app_ref.emit("fileDrop", {"x" => x, "y" => y, "paths" => paths})
            }
          end

          Native::Window.setup_file_drop(handle, on_drop, on_pos)
        end

        if load_cb = @options.on_load
          wv.on_load = -> {
            begin
              load_cb.call
            rescue ex
              Lune.logger.error { "on_load callback failed: #{ex.message}" }
              Lune.logger.debug(exception: ex) { "on_load callback failed (stacktrace)" }
            end
          }
        end

        if nav_cb = @options.on_navigate
          wv.bind("__lune_navigate", Webview::JSProc.new { |args|
            begin
              nav_cb.call(args[0]?.try(&.as_s) || "")
            rescue ex
              Lune.logger.error { "on_navigate callback failed: #{ex.message}" }
              Lune.logger.debug(exception: ex) { "on_navigate callback failed (stacktrace)" }
            end
            JSON::Any.new(nil)
          })
        end

        app_ref = @app
        wv.bind("__lune_js_emit", Webview::JSProc.new { |args|
          event = args[0]?.try(&.as_s) || ""
          data = args[1]? || JSON::Any.new(nil)
          app_ref.dispatch_event(event, data)
          JSON::Any.new(nil)
        })

        wv.init(Runtime::Scripts.core)
        wv.init(Runtime::Scripts::NAVIGATION) if @options.on_navigate
        wv.init(Runtime::Scripts::DISABLE_CONTEXT_MENU) if @options.disable_context_menu

        {% if flag?(:darwin) %}
          unless @options.drag_zone.empty?
            wv.init(Runtime::Scripts.drag_zone(@options.drag_zone, @options.drag_value))
          end
        {% end %}

        if should_drop
          drop_prop = @options.drop_zone.empty? ? nil : @options.drop_zone
          drop_val = @options.drop_zone.empty? ? nil : @options.drop_value
          wv.init(Runtime::Scripts.file_drop(drop_prop, drop_val))
        end

        # asset_server is only set in the embedded-assets branch; it is stopped
        # after wv.run returns so the port is released when the window closes.
        asset_server : AssetServer? = nil

        if h = html
          wv.html = h
        elsif u = url
          wv.navigate(u)
        elsif dev_url = ENV[Lune::ENV_DEV_URL]?
          all_bindings = @app.bindings + runtime_app.bindings + native_app.bindings
          Lune::Runtime::Generator.write_js(all_bindings, @lunejs_dir)
          wv.navigate(dev_url)
        elsif !Assets.empty?
          s = AssetServer.new
          s.start
          wv.navigate(s.url)
          asset_server = s
        else
          raise "Lune.run: provide html:, url:, LUNE_DEV_URL, or assets:"
        end

        wv.run

        x, y, width, height = Native::Window.get_frame(handle)
        WindowState.save(window_app_name, x, y, width, height)

        asset_server.try(&.stop)
        bridge.close!
        @options.on_close.try(&.call)
      end
    end
  end
end
