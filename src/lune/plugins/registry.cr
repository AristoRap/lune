module Lune
  module Plugins
    struct ResolvedSet
      getter plugins : Array(Lune::Plugin)
      getter warnings : Array(String)

      def initialize(@plugins, @warnings)
      end

      def active_ids : Set(Symbol)
        Set.new(@plugins.map(&.descriptor.id))
      end

      # Injects plugin sentinels and calls init_webview for every WebviewInject
      # plugin in this set. Safe for both the main window and secondary windows —
      # plugins that own shared resources (e.g. Stream) detect reuse internally
      # and connect as clients instead of re-initialising.
      def init_all_webviews(wv : Webview::Webview, handle : Pointer(Void), app : Lune::App) : Nil
        ids = active_ids
        ctx = Lune::Plugin::WebviewCtx.new(wv, handle, app, ids)
        bm = Lune::Plugin::BRIDGE_MARKER

        @plugins.each do |plugin|
          wv.init("window[#{plugin.sentinel_key.inspect}] = true;")
          plugin.init_webview(ctx) if plugin.is_a?(Lune::Plugin::WebviewInject)
          if js = plugin.init_js
            wv.init(js)
          end
        end

        unless ids.includes?(:events)
          # No-op helpers for code that may call window.__lune.on/off/crystalEmit
          # when the Events plugin is excluded. The Events.emit binding itself
          # isn't here either; user code that imports `runtime.Events.emit`
          # would get a ReferenceError from the generated runtime.js — which is
          # the right shape because they've opted the plugin out.
          wv.init("(function(){window.#{bm}=window.#{bm}||{};var n=function(){};window.#{bm}.crystalEmit=n;window.#{bm}.on=n;window.#{bm}.off=n;})();")
        end
        unless ids.includes?(:stream)
          wv.init("(function(){window.#{bm}=window.#{bm}||{};var n=function(){};window.#{bm}.stOn=n;window.#{bm}.stOff=n;window.#{bm}.stSend=n;})();")
        end
      end
    end

    # Compile-time resolution of the current platform. Plugins whose
    # descriptor's `platforms` list excludes this symbol are dropped at registry
    # construction time — they don't get setup, don't appear in `all`, and never
    # reach the JS runtime generator.
    CURRENT_PLATFORM = {% if flag?(:darwin) %}
                         :darwin
                       {% elsif flag?(:linux) %}
                         :linux
                       {% elsif flag?(:win32) %}
                         :win32
                       {% else %}
                         :unknown
                       {% end %}

    class Registry
      WILDCARD = {"*", "all"}

      @all : Array(Lune::Plugin)
      @known_names : Set(String)
      @platform_filtered : Array(Lune::Plugin)

      def initialize(
        handle : Void*,
        options : Lune::Options,
        on_quit : -> Nil = -> { },
      )
        # Registry consumes whatever's registered via `Lune.use` — built-ins
        # call `use` from `src/lune/plugins/builtins.cr` at require time, so
        # by the time we get here they're already in the array (alongside any
        # third-party plugins user code registered before `Lune.run`).
        all_plugins = Lune.registered_plugins

        # Names of every plugin regardless of platform — used by validate() to
        # distinguish a typo ("unknown") from a platform skip ("known but n/a").
        @known_names = Set(String).new(all_plugins.map(&.name))

        # @all is the platform-available subset. Single source of truth for what
        # can actually run here. Caps filtered out at this step never get setup
        # and never participate in resolve / generator output.
        @all = all_plugins.select { |plugin| plugin.descriptor.platforms.includes?(CURRENT_PLATFORM) }
        @platform_filtered = all_plugins - @all

        setup_ctx = Lune::Plugin::SetupCtx.new(options, handle, on_quit)
        @all.each { |plugin| plugin.setup(setup_ctx) }
      end

      def platform_filtered : Array(Lune::Plugin)
        @platform_filtered
      end

      def all : Array(Lune::Plugin)
        @all
      end

      # Apply enabled/disabled config, cascade-drop plugins whose hard deps
      # are inactive, and return a topologically sorted ResolvedSet with warnings.
      def resolve(config : Config::Plugins) : ResolvedSet
        warnings = [] of String

        # If the user explicitly listed plugins via `enabled:` and any of those are
        # known plugins that simply don't run on this platform, log it as
        # info — they asked for it, we owe them an ack that it was skipped.
        # Default-enabled plugins are silently filtered (no noise for lune.yml
        # files shared across platforms).
        if (req = config.enabled) && !req.empty? && !req.any? { |s| WILDCARD.includes?(s) }
          available_names = Set(String).new(@all.map(&.name))
          req.each do |n|
            if @known_names.includes?(n) && !available_names.includes?(n)
              Lune.logger.info { "Plugin #{n.inspect} skipped — not available on #{CURRENT_PLATFORM}" }
            end
          end
        end

        # Step 1: apply user enabled/disabled to get the initial active set
        active = apply_config(@all, config)
        active_ids = Set.new(active.map(&.descriptor.id))

        # Step 2: cascade — if a hard dep is inactive, drop the dependent too
        changed = true
        while changed
          changed = false
          active.reject! do |plugin|
            missing = plugin.descriptor.deps.find { |dep| !active_ids.includes?(dep) }
            if missing
              warnings << "#{plugin.descriptor.label} disabled — requires #{missing} (not active)"
              active_ids.delete(plugin.descriptor.id)
              changed = true
              true
            else
              false
            end
          end
        end

        # Step 3: soft dep warnings (plugin stays active but dep is absent)
        active.each do |plugin|
          plugin.descriptor.soft_deps.each do |dep|
            unless active_ids.includes?(dep)
              warnings << "#{plugin.descriptor.label} — soft dependency #{dep} is not active"
            end
          end
        end

        # Step 4: topological sort (deps before dependents)
        sorted = topological_sort(active)

        ResolvedSet.new(sorted, warnings)
      end

      # Warn about unknown names in the config enabled/disabled lists.
      # A name that's known but unavailable on this platform is NOT unknown —
      # it'll get info-logged by resolve() instead.
      def validate(config : Config::Plugins) : Nil
        check = ->(names : Array(String), field : String) {
          names.each do |n|
            next if WILDCARD.includes?(n) || @known_names.includes?(n)
            safe = n.gsub(/[[:cntrl:]]/, "")[0, 64]
            Lune.logger.warn { "plugins.#{field}: unknown plugin \"#{safe}\" — ignored" }
          end
        }

        check.call(config.enabled || [] of String, "enabled")
        check.call(config.disabled || [] of String, "disabled")
      end

      # Kept for the runner until it switches to resolve().
      def active(config : Config::Plugins) : Array(Lune::Plugin)
        apply_config(@all, config)
      end

      # Validate → resolve → log warnings → install BindPhase plugins into `target`.
      # Both the runtime path and build-mode path do this exact sequence; keep
      # them in lockstep so a new step (e.g. another phase) lands in one place.
      def validate_resolve_install(config : Config::Plugins, target : Lune::App) : ResolvedSet
        validate(config)
        resolved = resolve(config)
        resolved.warnings.each { |w| Lune.logger.warn { w } }
        resolved.plugins.each(&.install(target))
        resolved
      end

      private def apply_config(plugins : Array(Lune::Plugin), config : Config::Plugins) : Array(Lune::Plugin)
        en = config.enabled
        di = config.disabled

        result = if en && !en.empty? && !en.any? { |s| WILDCARD.includes?(s) }
                   plugins.select { |plugin| en.includes?(plugin.name) }
                 else
                   plugins.dup
                 end

        if di && !di.empty?
          if di.any? { |s| WILDCARD.includes?(s) }
            result = [] of Lune::Plugin
          else
            result = result.reject { |plugin| di.includes?(plugin.name) }
          end
        end

        result
      end

      private def topological_sort(plugins : Array(Lune::Plugin)) : Array(Lune::Plugin)
        id_to_cap = plugins.each_with_object({} of Symbol => Lune::Plugin) do |plugin, h|
          h[plugin.descriptor.id] = plugin
        end
        visited = Set(Symbol).new
        sorted = [] of Lune::Plugin
        plugins.each { |plugin| topo_visit(plugin.descriptor.id, id_to_cap, visited, sorted) }

        sorted
      end

      private def topo_visit(id : Symbol, index : Hash(Symbol, Lune::Plugin), visited : Set(Symbol), result : Array(Lune::Plugin)) : Nil
        return if visited.includes?(id)
        visited << id
        plugin = index[id]?
        return unless plugin
        plugin.descriptor.deps.each { |dep| topo_visit(dep, index, visited, result) }
        result << plugin
      end
    end
  end
end
