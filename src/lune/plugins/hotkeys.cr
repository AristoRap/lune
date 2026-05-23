module Lune
  module Plugins
    class Hotkeys < Lune::Plugin
      include Lune::Bindable
      include Plugin::Lifecycle

      DESCRIPTOR = Descriptor.new(id: :hotkeys, label: "Hotkeys", soft_deps: [:event])

      def descriptor : Descriptor
        DESCRIPTOR
      end

      # Hook the macro-generated install to also start the native pump that
      # delivers hotkey events back to JS via `app.event`.
      def install(app : Lune::App) : Nil
        previous_def
        Native::Hotkeys.init do |accelerator|
          app.event.emit("hotkey", {"key" => accelerator})
        end
      end

      # async so the callback runs on the @async_pool (Parallel) instead of
      # the webview Isolated thread — Native::Hotkeys.register blocks on a
      # reply Channel from the dedicated pump thread, which would raise
      # "Concurrency is disabled" if called from Isolated.
      @[Lune::Bind(async: true)]
      def register(accelerator : String) : Nil
        Lune.logger.warn { "Hotkeys.register: could not register #{accelerator.inspect}" } unless Native::Hotkeys.register(accelerator)
      end

      @[Lune::Bind(async: true)]
      def unregister(accelerator : String) : Nil
        Native::Hotkeys.unregister(accelerator)
      end

      def shutdown : Nil
        Native::Hotkeys.unregister_all
      end

      def js_helpers : String
        bm = BRIDGE_MARKER
        <<-JS
          on(cb)   { window.#{bm}.on("hotkey", cb, -1); },
          once(cb) { window.#{bm}.on("hotkey", cb, 1); },
          off(cb)  { window.#{bm}.off("hotkey", cb); },
        JS
      end

      def dts_helpers : String
        <<-DTS
          on(cb: (event: { key: string }) => void): void;
          once(cb: (event: { key: string }) => void): void;
          off(cb?: (event: { key: string }) => void): void;
        DTS
      end
    end
  end
end
