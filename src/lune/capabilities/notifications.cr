module Lune
  module Capabilities
    class Notifications < Lune::Capability
      include Capability::BindPhase

      DESCRIPTOR = Descriptor.new(id: :notifications, label: "Notifications")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      def install(ctx : BindCtx) : Nil
        # async because Native::Notifications.show shells out to PowerShell on
        # Win32 (Process.run), which uses Channel internally and would raise
        # Concurrency-disabled if called from the webview Isolated thread.
        ctx.define("notify",
          args: ["String", "String"],
          arg_names: ["title", "body"],
          async: true,
        ) do |args|
          Lune::Native::Notifications.show(args[0].as_s, args[1].as_s)
          JSON::Any.new(nil)
        end
      end
    end
  end
end
