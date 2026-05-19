module Lune
  module Capabilities
    class Registry
      WILDCARD = {"*", "all"}

      def initialize(
        handle : Void*,
        options : Lune::Options,
        on_quit : -> Nil = -> { },
      )
        @all = [
          # Core (JS injection via wv.init / raw wv.bind)
          Capabilities::EventBus.new,
          Capabilities::Channel.new,
          Capabilities::FileDrop.new,
          # Runtime (bridge bindings)
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
        ] of Lune::Capability

        setup_ctx = Lune::Capability::SetupCtx.new(options, handle)
        @all.each { |cap| cap.setup(setup_ctx) }
      end

      # All capabilities, unfiltered.
      def all : Array(Lune::Capability)
        @all
      end

      # Capabilities filtered by lune.yml include/exclude. Matching is by capability name only.
      # Pipeline: all → include-select → exclude-reject.
      def active(config : ConfigCapabilities) : Array(Lune::Capability)
        inc = config.only
        exc = config.exclude

        result = if inc && !inc.empty? && !inc.any? { |s| WILDCARD.includes?(s) }
                   @all.select { |cap| inc.includes?(cap.name) }
                 else
                   @all.dup
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
    end
  end
end
