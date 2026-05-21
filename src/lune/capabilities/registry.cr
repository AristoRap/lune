module Lune
  module Capabilities
    struct ResolvedSet
      getter capabilities : Array(Lune::Capability)
      getter warnings : Array(String)

      def initialize(@capabilities, @warnings)
      end

      def active_ids : Set(Symbol)
        Set.new(@capabilities.map(&.descriptor.id))
      end

      # Injects capability sentinels and calls init_webview for every WebviewInject
      # capability in this set. Safe for both the main window and secondary windows —
      # capabilities that own shared resources (e.g. Stream) detect reuse internally
      # and connect as clients instead of re-initialising.
      def init_all_webviews(wv : Webview::Webview, handle : Pointer(Void), app : Lune::App) : Nil
        ids = active_ids
        ctx = Lune::Capability::WebviewCtx.new(wv, handle, app, ids)
        bm = Lune::Capability::BRIDGE_MARKER

        @capabilities.each do |cap|
          wv.init("window[#{cap.sentinel_key.inspect}] = true;")
          cap.init_webview(ctx) if cap.is_a?(Lune::Capability::WebviewInject)
        end

        unless ids.includes?(:events)
          js_emit_key = "#{bm}.jsEmit"
          wv.init("(function(){window.#{bm}=window.#{bm}||{};var n=function(){};window.#{bm}.crystalEmit=n;window.#{bm}.on=n;window.#{bm}.off=n;window[#{js_emit_key.inspect}]=function(){return Promise.resolve();};})();")
        end
        unless ids.includes?(:stream)
          wv.init("(function(){window.#{bm}=window.#{bm}||{};var n=function(){};window.#{bm}.stOn=n;window.#{bm}.stOff=n;window.#{bm}.stSend=n;})();")
        end
      end
    end

    # Compile-time resolution of the current platform. Capabilities whose
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

      @all : Array(Lune::Capability)
      @known_names : Set(String)
      @platform_filtered : Array(Lune::Capability)

      def initialize(
        handle : Void*,
        options : Lune::Options,
        on_quit : -> Nil = -> { },
      )
        all_caps = [
          Capabilities::Events.new,
          Capabilities::Stream.new,
          Capabilities::FileDrop.new,
          Capabilities::System.new(on_quit),
          Capabilities::Filesystem.new,
          Capabilities::Clipboard.new,
          Capabilities::Window.new,
          Capabilities::Dialogs.new,
          Capabilities::Tray.new,
          Capabilities::Notifications.new,
          Capabilities::Screen.new,
          Capabilities::ContextMenu.new,
          Capabilities::DragOut.new,
          Capabilities::DeepLink.new,
          Capabilities::FileWatch.new,
          Capabilities::Shell.new,
          Capabilities::Hotkeys.new,
          Capabilities::Sqlite.new,
          Capabilities::Kv.new,
          Capabilities::Windows.new,
          Capabilities::EditShortcuts.new,
          Capabilities::Navigation.new,
          Capabilities::WindowDrag.new,
          Capabilities::ContextMenuBlocker.new,
        ] of Lune::Capability

        # Names of every cap regardless of platform — used by validate() to
        # distinguish a typo ("unknown") from a platform skip ("known but n/a").
        @known_names = Set(String).new(all_caps.map(&.name))

        # @all is the platform-available subset. Single source of truth for what
        # can actually run here. Caps filtered out at this step never get setup
        # and never participate in resolve / generator output.
        @all = all_caps.select { |cap| cap.descriptor.platforms.includes?(CURRENT_PLATFORM) }
        @platform_filtered = all_caps - @all

        setup_ctx = Lune::Capability::SetupCtx.new(options, handle)
        @all.each { |cap| cap.setup(setup_ctx) }
      end

      def platform_filtered : Array(Lune::Capability)
        @platform_filtered
      end

      def all : Array(Lune::Capability)
        @all
      end

      # Apply enabled/disabled config, cascade-drop capabilities whose hard deps
      # are inactive, and return a topologically sorted ResolvedSet with warnings.
      def resolve(config : ConfigCapabilities) : ResolvedSet
        warnings = [] of String

        # If the user explicitly listed caps via `enabled:` and any of those are
        # known capabilities that simply don't run on this platform, log it as
        # info — they asked for it, we owe them an ack that it was skipped.
        # Default-enabled caps are silently filtered (no noise for lune.yml
        # files shared across platforms).
        if (req = config.enabled) && !req.empty? && !req.any? { |s| WILDCARD.includes?(s) }
          available_names = Set(String).new(@all.map(&.name))
          req.each do |n|
            if @known_names.includes?(n) && !available_names.includes?(n)
              Lune.logger.info { "Capability #{n.inspect} skipped — not available on #{CURRENT_PLATFORM}" }
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
          active.reject! do |cap|
            missing = cap.descriptor.deps.find { |dep| !active_ids.includes?(dep) }
            if missing
              warnings << "#{cap.descriptor.label} disabled — requires #{missing} (not active)"
              active_ids.delete(cap.descriptor.id)
              changed = true
              true
            else
              false
            end
          end
        end

        # Step 3: soft dep warnings (capability stays active but dep is absent)
        active.each do |cap|
          cap.descriptor.soft_deps.each do |dep|
            unless active_ids.includes?(dep)
              warnings << "#{cap.descriptor.label} — soft dependency #{dep} is not active"
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
      def validate(config : ConfigCapabilities) : Nil
        check = ->(names : Array(String), field : String) {
          names.each do |n|
            next if WILDCARD.includes?(n) || @known_names.includes?(n)
            safe = n.gsub(/[[:cntrl:]]/, "")[0, 64]
            Lune.logger.warn { "capabilities.#{field}: unknown capability \"#{safe}\" — ignored" }
          end
        }

        check.call(config.enabled || [] of String, "enabled")
        check.call(config.disabled || [] of String, "disabled")
      end

      # Kept for the runner until it switches to resolve().
      def active(config : ConfigCapabilities) : Array(Lune::Capability)
        apply_config(@all, config)
      end

      private def apply_config(caps : Array(Lune::Capability), config : ConfigCapabilities) : Array(Lune::Capability)
        en = config.enabled
        di = config.disabled

        result = if en && !en.empty? && !en.any? { |s| WILDCARD.includes?(s) }
                   caps.select { |cap| en.includes?(cap.name) }
                 else
                   caps.dup
                 end

        if di && !di.empty?
          if di.any? { |s| WILDCARD.includes?(s) }
            result = [] of Lune::Capability
          else
            result = result.reject { |cap| di.includes?(cap.name) }
          end
        end

        result
      end

      private def topological_sort(caps : Array(Lune::Capability)) : Array(Lune::Capability)
        id_to_cap = caps.each_with_object({} of Symbol => Lune::Capability) do |cap, h|
          h[cap.descriptor.id] = cap
        end
        visited = Set(Symbol).new
        sorted = [] of Lune::Capability
        caps.each { |cap| topo_visit(cap.descriptor.id, id_to_cap, visited, sorted) }

        sorted
      end

      private def topo_visit(id : Symbol, index : Hash(Symbol, Lune::Capability), visited : Set(Symbol), result : Array(Lune::Capability)) : Nil
        return if visited.includes?(id)
        visited << id
        cap = index[id]?
        return unless cap
        cap.descriptor.deps.each { |dep| topo_visit(dep, index, visited, result) }
        result << cap
      end
    end
  end
end
