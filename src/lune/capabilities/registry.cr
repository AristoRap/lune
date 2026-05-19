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
    end

    class Registry
      WILDCARD = {"*", "all"}

      def initialize(
        handle : Void*,
        options : Lune::Options,
        on_quit : -> Nil = -> { },
      )
        @all = [
          Capabilities::EventBus.new,
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
          Capabilities::Windows.new,
        ] of Lune::Capability

        setup_ctx = Lune::Capability::SetupCtx.new(options, handle)
        @all.each { |cap| cap.setup(setup_ctx) }
      end

      def all : Array(Lune::Capability)
        @all
      end

      # Apply include/exclude config, cascade-disable capabilities whose hard deps
      # are inactive, and return a topologically sorted ResolvedSet with warnings.
      def resolve(config : ConfigCapabilities) : ResolvedSet
        warnings = [] of String

        # Step 1: apply user include/exclude to get the initial enabled set
        enabled = apply_config(@all, config)
        enabled_ids = Set.new(enabled.map(&.descriptor.id))

        # Step 2: cascade — if a hard dep is disabled, disable the dependent too
        changed = true
        while changed
          changed = false
          enabled.reject! do |cap|
            missing = cap.descriptor.deps.find { |dep| !enabled_ids.includes?(dep) }
            if missing
              warnings << "#{cap.descriptor.label} disabled — requires #{missing} (not active)"
              enabled_ids.delete(cap.descriptor.id)
              changed = true
              true
            else
              false
            end
          end
        end

        # Step 3: soft dep warnings (capability stays active but dep is absent)
        enabled.each do |cap|
          cap.descriptor.soft_deps.each do |dep|
            unless enabled_ids.includes?(dep)
              warnings << "#{cap.descriptor.label} — soft dependency #{dep} is not active"
            end
          end
        end

        # Step 4: topological sort (deps before dependents)
        sorted = topological_sort(enabled)

        ResolvedSet.new(sorted, warnings)
      end

      # Warn about unknown names in the config include/exclude lists.
      def validate(config : ConfigCapabilities) : Nil
        known = Set(String).new
        @all.each { |cap| known << cap.name }

        check = ->(names : Array(String), field : String) {
          names.each do |n|
            next if WILDCARD.includes?(n) || known.includes?(n)
            safe = n.gsub(/[[:cntrl:]]/, "")[0, 64]
            Lune.logger.warn { "capabilities.#{field}: unknown capability \"#{safe}\" — ignored" }
          end
        }

        check.call(config.only || [] of String, "include")
        check.call(config.exclude || [] of String, "exclude")
      end

      # Kept for the runner until it switches to resolve().
      def active(config : ConfigCapabilities) : Array(Lune::Capability)
        apply_config(@all, config)
      end

      private def apply_config(caps : Array(Lune::Capability), config : ConfigCapabilities) : Array(Lune::Capability)
        inc = config.only
        exc = config.exclude

        result = if inc && !inc.empty? && !inc.any? { |s| WILDCARD.includes?(s) }
                   caps.select { |cap| inc.includes?(cap.name) }
                 else
                   caps.dup
                 end

        if exc && !exc.empty?
          if exc.any? { |s| WILDCARD.includes?(s) }
            result = [] of Lune::Capability
          else
            result = result.reject { |cap| exc.includes?(cap.name) }
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
