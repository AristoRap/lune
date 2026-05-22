module Lune
  module Plugins
    # Registers every built-in plugin via `Lune.use` at require time. Order
    # mirrors the dependency graph (Events / Stream first so plugins that
    # soft-depend on them resolve cleanly) but isn't load-bearing — `Registry`
    # runs a topological sort before install.
    def self.register_builtins! : Nil
      Lune.use(Events.new)
      Lune.use(Stream.new)
      Lune.use(FileDrop.new)
      Lune.use(System.new)
      Lune.use(Filesystem.new)
      Lune.use(Clipboard.new)
      Lune.use(Window.new)
      Lune.use(Dialogs.new)
      Lune.use(Tray.new)
      Lune.use(Notifications.new)
      Lune.use(Screen.new)
      Lune.use(ContextMenu.new)
      Lune.use(DragOut.new)
      Lune.use(DeepLink.new)
      Lune.use(FileWatch.new)
      Lune.use(Shell.new)
      Lune.use(Hotkeys.new)
      Lune.use(Sqlite.new)
      Lune.use(Kv.new)
      Lune.use(Windows.new)
      Lune.use(EditShortcuts.new)
      Lune.use(Navigation.new)
      Lune.use(WindowDrag.new)
    end
  end
end

Lune::Plugins.register_builtins!
