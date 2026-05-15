module Lune
  module Runtime
    module Bindings
      def self.filter(bindings : Array(Binding), capabilities : Array(String)?) : Array(Binding)
        return bindings if capabilities.nil?
        bindings.select { |b| capabilities.includes?(b.method.lchop("__lune.")) }
      end

      # Installs all runtime binding classes with no-op/null args so their
      # RuntimeBinding metadata is registered without requiring real handles or
      # callbacks. Used in build mode to populate the full binding list for JS/DTS generation.
      def self.register_stubs(app : Lune::App)
        Lifecycle.new(on_quit: -> {}).install(app)
        Filesystem.new.install(app)
        Clipboard.new.install(app)
        Window.new(Pointer(Void).null).install(app)
        Dialogs.new.install(app)
        Tray.new.install(app)
        Notifications.new.install(app)
        Screen.new.install(app)
      end
    end
  end
end
