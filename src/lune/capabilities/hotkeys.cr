module Lune
  module Capabilities
    class Hotkeys < Lune::Capability
      include Capability::Bindable
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

        ctx.register(Definition.new(
          name: "#{name}.register",
          args: ["String"],
          return_type: "Nil",
          arg_names: ["accelerator"],
          callback: ->(args : Array(JSON::Any)) {
            acc = args[0].as_s
            Lune.logger.warn { "Hotkeys.register: could not register #{acc.inspect}" } unless Native::Hotkeys.register(acc)
            JSON::Any.new(nil)
          },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.unregister",
          args: ["String"],
          return_type: "Nil",
          arg_names: ["accelerator"],
          callback: ->(args : Array(JSON::Any)) {
            Native::Hotkeys.unregister(args[0].as_s)
            JSON::Any.new(nil)
          },
        ).binding(binding_namespace))
      end

      def shutdown : Nil
        Native::Hotkeys.unregister_all
      end

      def js_helpers : String
        bm = BRIDGE_MARKER
        <<-JS
          register(accelerator)   { return __lune.call(#{("#{bm}.#{name}.register").inspect}, accelerator); },
          unregister(accelerator) { return __lune.call(#{("#{bm}.#{name}.unregister").inspect}, accelerator); },
          on(cb)                  { window.#{bm}.on("hotkey", cb, -1); },
          once(cb)                { window.#{bm}.on("hotkey", cb, 1); },
          off(cb)                 { window.#{bm}.off("hotkey", cb); },
        JS
      end

      def dts_helpers : String
        <<-DTS
          register(accelerator: string): Promise<void>;
          unregister(accelerator: string): Promise<void>;
          on(cb: (event: { key: string }) => void): void;
          once(cb: (event: { key: string }) => void): void;
          off(cb?: (event: { key: string }) => void): void;
        DTS
      end
    end
  end
end
