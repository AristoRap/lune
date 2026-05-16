module Lune
  # Controls the macOS window appearance. Used with `opts.mac.appearance`.
  enum MacAppearance
    Auto  # follows the system setting (default)
    Dark
    Light
  end

  # macOS-specific window options, accessible via `opts.mac`.
  #
  # ```
  # Lune.run(app) do |opts|
  #   opts.mac.full_size_content = true
  #   opts.mac.transparent       = true
  #   opts.mac.appearance        = Lune::MacAppearance::Dark
  # end
  # ```
  class MacOptions
    # Extends the content view to fill the entire window including under the title bar,
    # and makes the title bar itself transparent. The traffic lights remain visible.
    property full_size_content : Bool = false

    # Clears the window and webview background so CSS `backdrop-filter` effects
    # (e.g. blur) show through to whatever is behind the window.
    property transparent : Bool = false

    # Hides the window title text while keeping the title bar (and traffic lights) visible.
    # Commonly combined with `full_size_content` for a clean custom header.
    property hide_title : Bool = false

    # Forces a specific appearance mode for the window. Defaults to `Auto` (system setting).
    property appearance : MacAppearance = MacAppearance::Auto

    # Prevents the window content from being captured by screenshots or screen recording.
    property content_protection : Bool = false

    # Keeps the window above all other windows, including those from other apps.
    property always_on_top : Bool = false

    def initialize; end
  end

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

    # Called once immediately after the native window is created, before any
    # page navigation begins. Receives the platform-specific native window
    # handle (NSWindow* on macOS, GtkWindow* on Linux, HWND on Windows).
    property on_window_ready : (Void* -> Nil)?

    # Called when the tray icon is clicked (no menu attached).
    property on_tray_click : (-> Nil)?

    # Called when a tray context menu item is selected. Receives the item id.
    property on_menu_click : (String -> Nil)?

    # Called when the user drops files onto the window. Receives an array of absolute file paths.
    property on_file_drop : (Array(String) -> Nil)?

    # CSS custom property name that marks an element as a window drag handle.
    # When non-empty, any element with this property set to `drag_value` (and its
    # descendants) can be used to drag the window. Example: `"--lune-draggable"`.
    property drag_zone : String = ""

    # CSS value that activates drag behaviour. Defaults to `"drag"`.
    property drag_value : String = "drag"

    # When true, suppresses the browser's default right-click context menu.
    property disable_context_menu : Bool = false

    # macOS-specific window options.
    getter mac : MacOptions = MacOptions.new

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
      @on_window_ready = nil
      @on_tray_click = nil
      @on_menu_click = nil
      @on_file_drop = nil
      @drag_zone = ""
      @drag_value = "drag"
      @disable_context_menu = false
      @mac = MacOptions.new
    end

    def apply(window : Config::Window)
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
