require "./lune/asset_server"
require "./lune/assets"
require "./lune/logger"
require "./lune/webview"
require "./lune/bindable"
require "./lune/bridge"
require "./lune/runtime"
require "./lune/installable"
require "./lune/app"
require "./lune/single_instance"
require "./lune/runtime_bindings"

module Lune
  VERSION = "0.2.4"

  # Navigation priority (first match wins):
  #   1. html:   — inline HTML string (useful for tests and simple apps)
  #   2. url:    — explicit URL
  #   3. LUNE_DEV_URL env var — Vite dev server (set automatically by the CLI)
  #   4. assets: — directory embedded at compile time, served locally in prod
  #
  # The block receives a Lune::App for binding setup and runs before navigation,
  # so all bindings are registered before the first page load.
  #
  #   Lune.run(title: "My App", assets: "frontend/dist") do |app|
  #     app.bind_typed("greet", String) { |msg| "Hello, #{msg}!" }
  #   end
  macro run(**options, &block)
    {% if options[:assets] %}
      ::Lune::Assets.embed_dir({{ options[:assets] }})
    {% end %}
    ::Lune.__run(
      {% for key, val in options %}
        {% unless key.stringify == "assets" %}
          {{ key }}: {{ val }},
        {% end %}
      {% end %}
    ) do |{{ block.args.first || "app".id }}|
      {{ block.body }}
    end
  end

  {% if flag?(:win32) %}
    def self.__run(
      title : String,
      width : Int32 = 1024,
      height : Int32 = 768,
      hint : Webview::SizeHints = Webview::SizeHints::NONE,
      resizable : Bool = true,
      min_width : Int32? = nil,
      min_height : Int32? = nil,
      max_width : Int32? = nil,
      max_height : Int32? = nil,
      debug : Bool = false,
      html : String? = nil,
      url : String? = nil,
      on_load : (-> Nil)? = nil,
      on_navigate : (String -> Nil)? = nil,
      on_close : (-> Nil)? = nil,
      &block : App -> Nil
    )
      STDOUT.sync = true
      actual_hint = resizable ? hint : Webview::SizeHints::FIXED
      done = Channel(Exception?).new(1)
      Fiber::ExecutionContext::Isolated.new("webview") do
        __run_webview(width, height, actual_hint, title, debug, min_width, min_height, max_width, max_height, html, url, on_load, on_navigate, on_close, &block)
        done.send(nil)
      rescue ex
        done.send(ex)
      end
      done.receive.try { |ex| raise ex }
    end
  {% else %}
    def self.__run(
      title : String,
      width : Int32 = 1024,
      height : Int32 = 768,
      hint : Webview::SizeHints = Webview::SizeHints::NONE,
      resizable : Bool = true,
      min_width : Int32? = nil,
      min_height : Int32? = nil,
      max_width : Int32? = nil,
      max_height : Int32? = nil,
      debug : Bool = false,
      html : String? = nil,
      url : String? = nil,
      on_load : (-> Nil)? = nil,
      on_navigate : (String -> Nil)? = nil,
      on_close : (-> Nil)? = nil,
      &block : App -> Nil
    )
      STDOUT.sync = true
      actual_hint = resizable ? hint : Webview::SizeHints::FIXED
      __run_webview(width, height, actual_hint, title, debug, min_width, min_height, max_width, max_height, html, url, on_load, on_navigate, on_close, &block)
    end
  {% end %}

  private def self.__run_webview(
    width : Int32,
    height : Int32,
    actual_hint : Webview::SizeHints,
    title : String,
    debug : Bool,
    min_width : Int32?,
    min_height : Int32?,
    max_width : Int32?,
    max_height : Int32?,
    html : String?,
    url : String?,
    on_load : (-> Nil)?,
    on_navigate : (String -> Nil)?,
    on_close : (-> Nil)?,
    &block : App -> Nil
  )
    Webview.with_window(width, height, actual_hint, title, debug) do |wv|
      wv.size(min_width || 0, min_height || 0, Webview::SizeHints::MIN) if min_width || min_height
      wv.size(max_width || 0, max_height || 0, Webview::SizeHints::MAX) if max_width || max_height

      bridge = Bridge.new(wv)
      app = App.new(bridge)

      RuntimeBindings.register(bridge, on_quit: -> { wv.dispatch { wv.terminate } }, debug: debug)

      block.call(app)

      wv.on_load = on_load

      if nav_cb = on_navigate
        wv.bind("__lune_navigate", Webview::JSProc.new { |args|
          nav_cb.call(args[0]?.try(&.as_s) || "")
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
      elsif dev_url = ENV["LUNE_DEV_URL"]?
        lunejs_dir = File.join(ENV.fetch("LUNE_FRONTEND_DIR", "frontend"), "lunejs")
        Runtime.write_js(app.binding_names, lunejs_dir)
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
      app.close!
      on_close.try(&.call)
    end
  end
end
