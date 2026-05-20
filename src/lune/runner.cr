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
        {% end %}

        registry = Capabilities::Registry.new(handle, @options, on_quit: -> { wv.dispatch { wv.terminate } })
        registry.validate(@config.capabilities)
        resolved = registry.resolve(@config.capabilities)
        resolved.warnings.each { |w| Lune.logger.warn { w } }

        bind_ctx = Lune::Capability::BindCtx.new(@app)
        resolved.capabilities.each do |cap|
          cap.install(bind_ctx) if cap.is_a?(Lune::Capability::Bindable)
        end

        bridge = Bridge.new(wv)
        bridge.register_bindings(@app.bindings.reject(&.internal?))
        bridge.register_bindings(@app.bindings.select(&.internal?))
        @app.bridge = bridge

        if windows_cap = resolved.capabilities.find { |c| c.is_a?(Capabilities::Windows) }.as?(Capabilities::Windows)
          windows_cap.set_context(wv, @app, resolved, @app.bindings)
        end

        callback_window_ready_if_set(handle)

        window_app_name = WindowState.app_name(@options.title)
        if saved = WindowState.load(window_app_name)
          Native::Window.set_frame(handle, saved[:x], saved[:y], saved[:width], saved[:height])
        end

        callback_window_loaded_if_set(wv)

        if @options.disable_context_menu
          wv.init("document.addEventListener('contextmenu',function(e){e.preventDefault();});")
        end

        setup_keyboard_shortcuts(wv)
        setup_navigate_if_set(wv)
        setup_drag_zone_if_set(wv, handle)

        resolved.init_all_webviews(wv, handle, @app)

        asset_server = setup_navigation(wv, html, url, registry, resolved)

        wv.run

        resolved.capabilities.each do |cap|
          cap.shutdown if cap.is_a?(Lune::Capability::Lifecycle)
        end

        x, y, width, height = Native::Window.get_frame(handle)
        WindowState.save(window_app_name, x, y, width, height)

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

    private def setup_keyboard_shortcuts(wv : Webview::Webview) : Nil
      wv.init(<<-JS)
      (function(){
        document.addEventListener('keydown', function(e) {
          if (!e.metaKey && !e.ctrlKey) return;
          var cmd;
          switch (e.key) {
            case 'a': cmd = 'selectAll'; break;
            case 'c': cmd = 'copy'; break;
            case 'v': cmd = 'paste'; break;
            case 'x': cmd = 'cut'; break;
            case 'z': cmd = e.shiftKey ? 'redo' : 'undo'; break;
            case 'y': cmd = 'redo'; break;
          }
          if (cmd) { e.preventDefault(); document.execCommand(cmd); }
        });
      })();
      JS
    end

    private def setup_drag_zone_if_set(wv : Webview::Webview, handle : Pointer(Void)) : Nil
      css_var = @options.drag.zone
      return if css_var.empty?

      {% if flag?(:darwin) %}
        css_val = @options.drag.value
        start_drag_key = "#{Lune::Capability::BRIDGE_MARKER}.startDrag"

        Native::Window.setup_drag_monitor

        wv.bind(start_drag_key, Webview::JSProc.new { |_args|
          Native::Window.start_window_drag(handle)
          JSON::Any.new(nil)
        })

        wv.init(<<-JS)
        (function(){
          document.addEventListener('mousedown', function(e) {
            var el = e.target;
            while (el) {
              if (el.style && el.style.getPropertyValue(#{css_var.inspect}).trim() === #{css_val.inspect}) {
                window[#{start_drag_key.inspect}]();
                return;
              }
              el = el.parentElement;
            }
          }, true);
        })();
        JS
      {% end %}
    end

    private def setup_navigate_if_set(wv : Webview::Webview) : Nil
      return unless (nav_cb = @options.on_navigate)
      navigate_key = "#{Lune::Capability::BRIDGE_MARKER}.navigate"
      wv.bind(navigate_key, Webview::JSProc.new { |args|
        begin
          nav_cb.call(args[0]?.try(&.as_s) || "")
        rescue ex
          Lune.logger.error { "on_navigate callback failed: #{ex.message}" }
          Lune.logger.debug(exception: ex) { "on_navigate callback failed (stacktrace)" }
        end
        JSON::Any.new(nil)
      })
      wv.init(<<-JS)
      (function(){
        function _nav(){ window[#{navigate_key.inspect}](location.href); }
        window.addEventListener('popstate', _nav);
        window.addEventListener('hashchange', _nav);
      })();
      JS
    end

    private def setup_navigation(
      wv : Webview::Webview,
      html : String?,
      url : String?,
      registry : Capabilities::Registry,
      resolved : Capabilities::ResolvedSet,
    ) : AssetServer?
      if h = html
        wv.html = h
      elsif u = url
        wv.navigate(u)
      elsif dev_url = ENV[Lune::ENV_DEV_URL]?
        all_stubs = App.new
        all_bind_ctx = Lune::Capability::BindCtx.new(all_stubs)
        registry.all.each do |cap|
          next if resolved.active_ids.includes?(cap.descriptor.id)
          cap.install(all_bind_ctx) if cap.is_a?(Lune::Capability::Bindable)
        end
        Lune::Runtime::Generator.write_js(
          @app.bindings + all_stubs.bindings.select(&.internal?),
          @lunejs_dir,
          registry.all
        )
        wv.navigate(dev_url)
      elsif !Assets.empty?
        s = AssetServer.new
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
