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

      # Optional override: called when the tray icon is clicked (no menu attached).
      # When set, takes precedence over the default event emission.
      property on_click : (-> Nil)? = nil

      # Optional override: called when a tray context menu item is selected.
      # Receives the item id. When set, takes precedence over the default event emission.
      property on_menu_click : (String -> Nil)? = nil

      def initialize; end
    end
  end
end
