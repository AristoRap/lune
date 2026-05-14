module Lune
  # Configuration passed to `Lune.run` via its block parameter.
  #
  # ```
  # Lune.run(app) do |o|
  #   o.title  = "My App"
  #   o.width  = 1280
  #   o.height = 720
  #   o.on_load = -> { puts "ready" }
  # end
  # ```
  class Options
    # Window title bar text.
    property title : String

    # Initial window width in logical pixels.
    property width : Int32

    # Initial window height in logical pixels.
    property height : Int32

    # Size constraint mode (NONE, MIN, MAX, FIXED). Ignored when `resizable` is false — the hint is forced to FIXED.
    property hint : Webview::SizeHints

    # When false the window cannot be resized by the user (forces `hint` to FIXED).
    property resizable : Bool

    # Minimum window width in logical pixels. Applied in addition to `hint`.
    property min_width : Int32?

    # Minimum window height in logical pixels. Applied in addition to `hint`.
    property min_height : Int32?

    # Maximum window width in logical pixels. Applied in addition to `hint`.
    property max_width : Int32?

    # Maximum window height in logical pixels. Applied in addition to `hint`.
    property max_height : Int32?

    # Enable webview debug/inspector tools.
    property debug : Bool

    # Called on every client-side navigation with the new URL as argument.
    # Fires on `popstate` and `hashchange` events.
    property on_navigate : (String -> Nil)?

    # Called once after the webview window closes and the run loop exits.
    property on_close : (-> Nil)?

    # Called once when the page's `load` event fires (i.e. the DOM is ready).
    property on_load : (-> Nil)?

    def initialize
      @title = "Lune"
      @width = 1200
      @height = 800
      @hint = Webview::SizeHints::NONE
      @resizable = true
      @min_width = nil
      @min_height = nil
      @max_width = nil
      @max_height = nil
      @debug = false
      @on_navigate = nil
      @on_close = nil
      @on_load = nil
    end

    def apply(window : ProjectConfig::Window)
      if t = window.title;      @title      = t end
      if w = window.width;      @width      = w end
      if h = window.height;     @height     = h end
      if v = window.min_width;  @min_width  = v end
      if v = window.min_height; @min_height = v end
      if v = window.max_width;  @max_width  = v end
      if v = window.max_height; @max_height = v end
      unless (r = window.resizable).nil?; @resizable = r end
      unless (d = window.debug).nil?;     @debug     = d end
    end
  end
end
