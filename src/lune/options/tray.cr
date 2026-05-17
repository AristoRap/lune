module Lune
  class Options
    # Tray icon options, configured via `opts.tray { |t| ... }`.
    #
    # ```
    # Lune.run(app) do |opts|
    #   opts.tray do |t|
    #     t.on_click      = -> { app.emit("trayClick", nil) }
    #     t.on_menu_click = ->(id : String) { app.emit("trayMenu", id) }
    #   end
    # end
    # ```
    class Tray
      # Called when the tray icon is clicked (no menu attached).
      property on_click : (-> Nil)? = nil

      # Called when a tray context menu item is selected. Receives the item id.
      property on_menu_click : (String -> Nil)? = nil

      def initialize; end
    end
  end
end
