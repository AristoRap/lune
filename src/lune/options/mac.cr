module Lune
  class Options
    # Controls the macOS window appearance. Used within `opts.mac { |m| }`.
    class Mac
      enum Appearance
        Auto # follows the system setting (default)
        Dark
        Light
      end

      # Extends the content view to fill the entire window including under the title bar,
      # and makes the title bar itself transparent. The traffic lights remain visible.
      property full_size_content : Bool = false

      # Clears the window and webview background so CSS `backdrop-filter` effects
      # (e.g. blur) show through to whatever is behind the window.
      property transparent : Bool = false

      # Hides the window title text while keeping the title bar (and traffic lights) visible.
      # Commonly combined with `full_size_content` for a clean custom header.
      property hide_title : Bool = false

      # Hides the close, minimise, and zoom buttons (traffic lights).
      # Combine with `full_size_content` and `hide_title` for a fully chrome-free window.
      property hide_traffic_lights : Bool = false

      # Forces a specific appearance mode for the window. Defaults to `Auto` (system setting).
      property appearance : Appearance = Appearance::Auto

      # Prevents the window content from being captured by screenshots or screen recording.
      property content_protection : Bool = false

      # Keeps the window above all other windows, including those from other apps.
      property always_on_top : Bool = false

      # Hides the dock icon and anchors the window below the tray icon on click.
      # The tray click toggles visibility automatically; set `opts.tray.on_click` to override.
      property menubar_mode : Bool = false

      def initialize; end
    end
  end
end
