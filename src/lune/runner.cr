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

        if window_ready_cb = @options.on_window_ready
          begin
            window_ready_cb.call(handle)
          rescue ex
            Lune.logger.error { "on_window_ready callback failed: #{ex.message}" }
            Lune.logger.debug(exception: ex) { "on_window_ready callback failed (stacktrace)" }
          end
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
          wv.init(<<-JS)
            (function(){
              function _lune_nav(){ window.__lune_navigate(location.href); }
              window.addEventListener('popstate', _lune_nav);
              window.addEventListener('hashchange', _lune_nav);
            })();
          JS
        end

        wv.init(<<-JS)
          (function(){
          // Keyboard shortcuts (copy/paste/undo/redo/select-all)
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

          // Event bus — used by app.emit() on the Crystal side
          var _ll = {};
          window.__lune_emit = function(name, data) {
            var ls = _ll[name];
            if (!ls) return;
            var keep = [];
            for (var i = 0; i < ls.length; i++) {
              ls[i].cb(data);
              ls[i].n++;
              if (ls[i].max < 0 || ls[i].n < ls[i].max) keep.push(ls[i]);
            }
            _ll[name] = keep;
          };
          window.__lune_on = function(name, cb, max) {
            (_ll[name] = _ll[name] || []).push({ cb: cb, n: 0, max: max === undefined ? -1 : max });
          };
          window.__lune_off = function(name, cb) {
            if (!cb) { delete _ll[name]; return; }
            if (_ll[name]) _ll[name] = _ll[name].filter(function(e) { return e.cb !== cb; });
          };
          })();
        JS

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

        asset_server.try(&.stop)
        bridge.close!
        @options.on_close.try(&.call)
      end
    end
  end
end
