module Lune
  module Capabilities
    class Notifications < Lune::Capability
      include Lune::Bindable

      DESCRIPTOR = Descriptor.new(id: :notifications, label: "Notifications")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      # async because Native::Notifications.show shells out to PowerShell on
      # Win32 (Process.run), which uses Channel internally and would raise
      # Concurrency-disabled if called from the webview Isolated thread.
      @[Lune::Bind(async: true)]
      def notify(title : String, body : String) : Nil
        Lune::Native::Notifications.show(title, body)
      end
    end
  end
end
