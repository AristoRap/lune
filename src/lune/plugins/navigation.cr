module Lune
  module Plugins
    # Fires `opts.on_navigate(url)` whenever the page-side `popstate` or
    # `hashchange` event fires. No-op unless `opts.on_navigate` is set.
    class Navigation < Lune::Plugin
      include Plugin::WebviewInject

      DESCRIPTOR = Descriptor.new(id: :navigation, label: "Navigation")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @on_navigate : (String -> Nil)? = nil

      def setup(ctx : SetupCtx) : Nil
        @on_navigate = ctx.options.on_navigate
      end

      def init_webview(ctx : WebviewCtx) : Nil
        nav_cb = @on_navigate
        return unless nav_cb

        navigate_key = "#{Lune::Plugin::BRIDGE_MARKER}.navigate"
        ctx.wv.bind(navigate_key, Webview::JSProc.new { |args|
          begin
            nav_cb.call(args[0]?.try(&.as_s) || "")
          rescue ex
            Lune.logger.error { "on_navigate callback failed: #{ex.message}" }
            Lune.logger.debug(exception: ex) { "on_navigate callback failed (stacktrace)" }
          end
          JSON::Any.new(nil)
        })
      end

      # popstate / hashchange are the only events the browser fires on its
      # own; SPA routers (React Router, Vue Router, Next, …) navigate via
      # `history.pushState` / `replaceState`, which fire nothing. Monkey-patch
      # both so on_navigate sees every URL change. Dedupe by last forwarded
      # URL because vue-router hash mode calls pushState AND mutates
      # location.hash on every navigation — without the guard, every click
      # would fire on_navigate twice.
      def init_js : String?
        return nil unless @on_navigate
        navigate_key = "#{Lune::Plugin::BRIDGE_MARKER}.navigate"
        <<-JS
        (function(){
          var _last;
          function _nav(){
            var u = location.href;
            if (u === _last) return;
            _last = u;
            window[#{navigate_key.inspect}](u);
          }
          window.addEventListener('popstate', _nav);
          window.addEventListener('hashchange', _nav);
          var _push = history.pushState, _replace = history.replaceState;
          history.pushState = function(){ _push.apply(this, arguments); _nav(); };
          history.replaceState = function(){ _replace.apply(this, arguments); _nav(); };
        })();
        JS
      end
    end
  end
end
