module Lune
  module Plugins
    # Exposes the app's live RPC contract — the `Vow::Manifest` (every procedure
    # plus the custom types its signatures reference) — to the frontend. The
    # `manifest` binding rides the normal registry like any plugin method; the
    # injected `window.__lune.manifest` helper is a convenience wrapper over it.
    #
    # Whether the helper is injected follows `opts.devtools`: introspection is a
    # development affordance, so with devtools off `init_js` returns nil and the
    # wrapper never reaches the page. Whether the plugin exists at all is decided
    # by `lune.yml` (`disabled: [introspection]` removes it entirely), the same
    # as every other built-in.
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
