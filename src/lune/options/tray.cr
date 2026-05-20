module Lune
  class Options
    # Tray icon options, configured via `opts.tray { |t| ... }`.
    #
    # By default, tray icon clicks and menu selections emit `"trayEvent"` on the
    # event bus. Override `event` to use a different name, or set `on_click` /
    # `on_menu_click` for full Crystal-side control.
    #
    # ```
    # # zero-config — emits "trayEvent" automatically
    # # opts.tray is optional
    #
    # # custom event name
    # opts.tray do |t|
    #   t.event = "myTray"
    # end
    #
    # # full override
    # opts.tray do |t|
    #   t.on_click      = -> { puts "clicked" }
    #   t.on_menu_click = ->(id : String) { puts id }
    # end
    # ```
    class Tray
      # Event name emitted via the event bus on tray icon click and menu item
      # selection. Defaults to `"trayEvent"`. Ignored when `on_click` /
      # `on_menu_click` are set explicitly.
      property event : String = "trayEvent"

      # Optional override: called on left-click of the tray icon.
      # When set, takes precedence over every default behavior (toggle, menu, emit).
      property on_click : (-> Nil)? = nil

      # Optional override: called on right-click (or Ctrl-click) of the tray icon.
      # When set, takes precedence over every default behavior.
      property on_right_click : (-> Nil)? = nil

      # Optional override: called when a tray context menu item is selected.
      # Receives the item id. When set, takes precedence over the default event emission.
      property on_menu_click : (String -> Nil)? = nil

      # Click directions that toggle the app window (positioned below the tray icon
      # on macOS). Listed clicks override the menu/emit default; user `on_click` /
      # `on_right_click` overrides still win.
      #
      # Valid values: `:left_click`, `:right_click`.
      property toggle_window_on : Array(Symbol) = [] of Symbol

      # When true, the tray icon is shown automatically at app start without
      # requiring a JS `Tray.show("")` call. Auto-enabled by `mac.menubar_mode`.
      property auto_show : Bool = false

      def initialize; end
    end
  end
end
