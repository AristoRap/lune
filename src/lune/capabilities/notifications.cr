module Lune
  module Capabilities
    class Notifications < Lune::Capability
      include Capability::Bindable

      DESCRIPTOR = Descriptor.new(id: :notifications, label: "Notifications")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      def install(app : App) : Nil
        install(BindCtx.new(app))
      end

      def install(ctx : BindCtx) : Nil
        ctx.register(Definition.new(
          name: "#{name}.notify",
          args: ["String", "String"],
          return_type: "Nil",
          arg_names: ["title", "body"],
          callback: ->(args : Array(JSON::Any)) { Lune::Native::Notify.show(args[0].as_s, args[1].as_s); JSON::Any.new(nil) },
        ).binding(binding_namespace))
      end
    end
  end
end
