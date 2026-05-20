module Lune
  module Capabilities
    class Notifications < Lune::Capability
      include Capability::Bindable

      DESCRIPTOR = Descriptor.new(id: :notifications, label: "Notifications")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      def install(ctx : BindCtx) : Nil
        ctx.register(Definition.new(
          name: "#{name}.notify",
          args: ["String", "String"],
          return_type: "Nil",
          arg_names: ["title", "body"],
          # async because Native::Notifications.show shells out to PowerShell on
          # Win32 (Process.run), which uses Channel internally and would raise
          # Concurrency-disabled if called from the webview Isolated thread.
          async: true,
          callback: ->(args : Array(JSON::Any)) { Lune::Native::Notifications.show(args[0].as_s, args[1].as_s); JSON::Any.new(nil) },
        ).binding(binding_namespace))
      end
    end
  end
end
