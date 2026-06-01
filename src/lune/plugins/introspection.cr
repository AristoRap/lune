module Lune
  module Plugins
    # Exposes the app's live `Vow::Manifest` to the frontend over a normal
    # `manifest` binding. The `window.__lune.manifest` helper wrapper is injected
    # only when devtools are on (introspection is a development affordance);
    # `lune.yml` decides whether the plugin is present at all.
    class Introspection < Lune::Plugin
      include Lune::Bindable

      DESCRIPTOR = Descriptor.new(id: :introspection, label: "Introspection")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @devtools : Bool = false

      def setup(ctx : SetupCtx) : Nil
        @devtools = ctx.options.devtools
      end

      # The app's live manifest, computed on call so it reflects the fully
      # resolved binding set (its own `manifest` procedure included).
      @[Lune::Bind]
      def manifest : Vow::Manifest
        @app.manifest
      end

      # The `window.__lune.manifest()` convenience wrapper — calls the manifest
      # binding by its flat dispatch-id key (the shape the bridge exposes it
      # under) and returns its promise. Injected only when devtools are on.
      def init_js : String?
        return nil unless @devtools
        bm = BRIDGE_MARKER
        call_key = "#{binding_namespace.gsub("::", ".")}.manifest"
        <<-JS
        (function(){
          window.#{bm} = window.#{bm} || {};
          window.#{bm}.manifest = function(){ return window[#{call_key.inspect}]({}); };
        })();
        JS
      end
    end
  end
end
