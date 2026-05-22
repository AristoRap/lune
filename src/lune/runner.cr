module Lune
  class Runner
    getter options : Options

    def initialize(app : App, &block : Options -> Nil)
      STDOUT.sync = true
      @app = app
      @lunejs_dir = File.join(ENV.fetch(Lune::ENV_FRONTEND_DIR, Lune::DEFAULT_FRONTEND_DIR), Lune::LUNEJS_SUBDIR)
      @config = Config.load
      @options = Options.new
      @options.apply(@config.window)
      block.call(@options)
    end

    def start(html : String? = nil, url : String? = nil) : Nil
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
        start_sigchld_pump
        webview(html, url)
      {% end %}
    end

    # On Unix, Crystal's signal-loop fiber lives in the default execution
    # context (main thread). When wv.run hands the main thread to Cocoa/GTK,
    # that fiber is starved — so SIGCHLD signals queue up in the signal pipe
    # but never get dispatched, and `Process#wait` (used by `Process.run`)
    # hangs forever. Drain pending SIGCHLDs from a dedicated thread.
    {% unless flag?(:win32) %}
      private def start_sigchld_pump : Nil
        Fiber::ExecutionContext::Isolated.new("lune-sigchld-pump") do
          loop do
            Crystal::System::SignalChildHandler.call
            sleep 10.milliseconds
          end
        end
      end
    {% end %}

    private def webview(html : String? = nil, url : String? = nil) : Nil
      Webview.with_window(@options.width, @options.height, @options.hint, @options.title, @options.devtools) do |wv|
        wv.size(@options.min_width || 0, @options.min_height || 0, Webview::SizeHints::MIN) if @options.min_width || @options.min_height
        wv.size(@options.max_width || 0, @options.max_height || 0, Webview::SizeHints::MAX) if @options.max_width || @options.max_height

        set_user_menu_or_default

        handle = wv.native_handle(Webview::NativeHandleKind::UI_WINDOW)
        {% if flag?(:darwin) %}
          setup_mac_window_options(handle)
          # menubar_mode implies the tray icon must come up at boot — surface it
          # via the generic `tray.auto_show` flag so the plugin owns wiring.
          @options.tray.auto_show = true if @options.mac.menubar_mode
        {% end %}

        registry = Plugins::Registry.new(handle, @options, on_quit: -> { wv.dispatch { wv.terminate } })
        resolved = registry.validate_resolve_install(@config.plugins, @app)

        bridge = Bridge.new(wv)
        bridge.register_bindings(@app.bindings.reject(&.internal?))
        bridge.register_bindings(@app.bindings.select(&.internal?))
        @app.bridge = bridge

        main_ctx = Lune::Plugin::MainCtx.new(wv, @app, resolved, @app.bindings)
        resolved.plugins.each do |plugin|
          plugin.set_main_context(main_ctx) if plugin.is_a?(Lune::Plugin::MainContextAware)
        end

        callback_window_ready_if_set(handle)

        {% if flag?(:darwin) %}
          if @options.mac.menubar_mode
            setup_menubar_mode(handle)
          end
        {% end %}

        window_app_name = WindowState.app_name(@options.title)
        menubar_mode = {% if flag?(:darwin) %}@options.mac.menubar_mode{% else %}false{% end %}
        if @options.remember_frame && !menubar_mode
          if saved = WindowState.load(window_app_name)
            Native::Window.set_frame(handle, saved[:x], saved[:y], saved[:width], saved[:height])
          end
          {% if flag?(:win32) %}
            # See WindowState.start_tracker — on Windows the HWND is gone by
            # the time wv.run returns, so we have to capture the frame while
            # it's still alive.
            WindowState.start_tracker(window_app_name, handle)
          {% end %}
        end

        callback_window_loaded_if_set(wv)

        resolved.init_all_webviews(wv, handle, @app)

        asset_server = setup_navigation(wv, html, url, registry, resolved)

        wv.run

        resolved.plugins.each do |plugin|
          plugin.shutdown if plugin.is_a?(Lune::Plugin::Lifecycle)
        end

        {% unless flag?(:win32) %}
          # Windows persists the frame live via WindowState.start_tracker;
          # the HWND is already destroyed at this point.
          if @options.remember_frame && !menubar_mode
            x, y, width, height = Native::Window.get_frame(handle)
            WindowState.save(window_app_name, x, y, width, height)
          end
        {% end %}

        asset_server.try(&.stop)
        bridge.close!
        @options.on_close.try(&.call)
      end
    end

    private def set_user_menu_or_default : Nil
      if @options.menu.any?
        @app.menu_options = @options.menu
        Native::Menu.set_from_options(@options.menu, @options.title)
      else
        Native::Menu.setup_default(@options.title)
      end
    end

    private def setup_mac_window_options(handle : Pointer(Void)) : Nil
      mac = @options.mac
      Native::Window.set_titlebar_transparent(handle, true) if mac.full_size_content
      Native::Window.set_background_transparent(handle) if mac.transparent
      Native::Window.hide_title(handle) if mac.hide_title
      Native::Window.hide_traffic_lights(handle) if mac.hide_traffic_lights
      Native::Window.set_appearance(handle, mac.appearance.value) unless mac.appearance.auto?
      Native::Window.set_content_protection(handle, true) if mac.content_protection
      Native::Window.set_always_on_top(handle, true) if mac.always_on_top
    end

    {% if flag?(:darwin) %}
      # Menubar mode is purely a window-state preset: hide the dock icon, start
      # the window hidden, and auto-hide whenever it loses focus. Tray icon
      # appearance and click behavior are handled by the Tray plugin — see
      # `opts.tray.auto_show` and `opts.tray.toggle_window_on`.
      private def setup_menubar_mode(handle : Pointer(Void)) : Nil
        Native::Window.set_activation_policy_accessory
        Native::Window.hide(handle)
        Native::Window.auto_hide_on_resign_key(handle)
      end
    {% end %}

    private def callback_window_ready_if_set(handle : Pointer(Void)) : Nil
      if window_ready_cb = @options.on_window_ready
        begin
          window_ready_cb.call(handle)
        rescue ex
          Lune.logger.error { "on_window_ready callback failed: #{ex.message}" }
          Lune.logger.debug(exception: ex) { "on_window_ready callback failed (stacktrace)" }
        end
      end
    end

    private def setup_navigation(
      wv : Webview::Webview,
      html : String?,
      url : String?,
      registry : Plugins::Registry,
      resolved : Plugins::ResolvedSet,
    ) : Assets::Server?
      if h = html
        wv.html = h
      elsif u = url
        wv.navigate(u)
      elsif dev_url = ENV[Lune::ENV_DEV_URL]?
        all_stubs = App.new
        # `registry.all` is already platform-filtered, so every plugin here has a
        # working install path on the current OS — no NotImplementedError to
        # swallow. Caps that can't run on this platform are emitted as rejecting
        # JS stubs separately via `registry.platform_filtered` below.
        registry.all.each do |plugin|
          next if resolved.active_ids.includes?(plugin.descriptor.id)
          plugin.install(all_stubs)
        end
        Lune::Generator.write_js(
          @app.bindings + all_stubs.bindings.select(&.internal?),
          @lunejs_dir,
          registry.all,
          registry.platform_filtered,
        )
        wv.navigate(dev_url)
      elsif !Assets.empty?
        s = Assets::Server.new
        s.start
        wv.navigate(s.url)
        return s
      else
        raise "Lune.run: provide html:, url:, LUNE_DEV_URL, or assets:"
      end
      nil
    end

    private def callback_window_loaded_if_set(wv : Webview::Webview) : Nil
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
    end
  end
end
