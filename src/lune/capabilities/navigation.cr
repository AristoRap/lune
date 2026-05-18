module Lune
  module Capabilities
    class Navigation < Lune::Capability
      def initialize(@on_navigate : (String -> Nil)?)
      end

      def name : String
        "navigation"
      end

      def core? : Bool
        true
      end

      def configured? : Bool
        !@on_navigate.nil?
      end

      def init_webview(wv : Webview::Webview, handle : Pointer(Void), app : Lune::App) : Nil
        return unless (cb = @on_navigate)

        navigate_key = "#{BRIDGE_MARKER}.navigate"
        wv.init(<<-JS)
        (function(){
          function _nav(){ window[#{navigate_key.inspect}](location.href); }
          window.addEventListener('popstate', _nav);
          window.addEventListener('hashchange', _nav);
        })();
        JS

        wv.bind(navigate_key, Webview::JSProc.new { |args|
          begin
            cb.call(args[0]?.try(&.as_s) || "")
          rescue ex
            Lune.logger.error { "on_navigate callback failed: #{ex.message}" }
            Lune.logger.debug(exception: ex) { "on_navigate callback failed (stacktrace)" }
          end
          JSON::Any.new(nil)
        })
      end
    end
  end
end
