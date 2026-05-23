module Lune
  module Plugins
    # Registers every built-in plugin via `Lune.use` at require time. Order
    # mirrors the dependency graph (Events / Stream first so plugins that
    # soft-depend on them resolve cleanly) but isn't load-bearing — `Registry`
    # runs a topological sort before install.
    #
    # Each built-in is blessed before registration so it passes the
    # `Lune::Plugins::` namespace guard in `Lune.use` — the same guard that
    # rejects third-party plugins from squatting on the framework namespace.
    def self.register_builtins! : Nil
      builtins = [
        Events.new, Stream.new, FileDrop.new, System.new, Filesystem.new,
        Clipboard.new, Window.new, Dialogs.new, Tray.new,
        ContextMenu.new, DragOut.new, DeepLink.new, FileWatch.new,
        Shell.new, Hotkeys.new, Sqlite.new, Kv.new, Windows.new,
        EditShortcuts.new, Navigation.new,
      ] of ::Lune::Plugin
      builtins.each do |p|
        ::Lune._bless_builtin(p.class.name)
        ::Lune.use(p)
      end
    end
  end
end

Lune::Plugins.register_builtins!
