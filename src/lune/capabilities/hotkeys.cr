module Lune
  module Capabilities
    class Hotkeys < Lune::Capability
      include Capability::BindPhase
      include Capability::Lifecycle

      DESCRIPTOR = Descriptor.new(id: :hotkeys, label: "Hotkeys", soft_deps: [:events])

      def descriptor : Descriptor
        DESCRIPTOR
      end

      def install(ctx : BindCtx) : Nil
        app = ctx.app

        Native::Hotkeys.init do |accelerator|
          app.events.emit("hotkey", {"key" => accelerator})
        end

        # async so the callback runs on the @async_pool (Parallel) instead of
        # the webview Isolated thread — Native::Hotkeys.register blocks on a
        # reply Channel from the dedicated pump thread, which would raise
        # "Concurrency is disabled" if called from Isolated.
        ctx.define("register",
          args: ["String"],
          arg_names: ["accelerator"],
          async: true,
        ) do |args|
          acc = args[0].as_s
          Lune.logger.warn { "Hotkeys.register: could not register #{acc.inspect}" } unless Native::Hotkeys.register(acc)
          JSON::Any.new(nil)
        end

        ctx.define("unregister",
          args: ["String"],
          arg_names: ["accelerator"],
          async: true,
        ) do |args|
          Native::Hotkeys.unregister(args[0].as_s)
          JSON::Any.new(nil)
        end
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
