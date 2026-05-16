module Lune
  # Controls the macOS window appearance. Used within `opts.mac { |m| }`.
  enum MacAppearance
    Auto  # follows the system setting (default)
    Dark
    Light
  end

  # macOS-specific window options, configured via `opts.mac { |m| ... }`.
  #
  # ```
  # Lune.run(app) do |opts|
  #   opts.mac do |m|
  #     m.full_size_content = true
  #     m.transparent       = true
  #     m.appearance        = Lune::MacAppearance::Dark
  #   end
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

  # File drop options, configured via `opts.drop { |d| ... }`.
  #
  # ```
  # Lune.run(app) do |opts|
  #   opts.drop do |d|
  #     d.enabled = true
  #     d.zone    = "--lune-drop-target"
  #     d.on_drop = ->(x : Int32, y : Int32, paths : Array(String)) { puts paths.inspect; nil }
  #   end
  # end
  # ```
  class DropOptions
    # Enables native file drop. When true the webview's own drop handling is disabled
    # and the `fileDrop` event is emitted to JS on every drop.
    property enabled : Bool = false

    # Disables the webview's built-in drag handling without setting up a drop target.
    # Prevents files from accidentally opening/navigating in the webview.
    property disable_webview_drop : Bool = false

    # CSS custom property that marks an element as a drop zone.
    # e.g. "--lune-drop-target". Elements with this property set to `value`
    # receive the class `lune-drop-target-active` while a file is dragged over them.
    property zone : String = ""

    # CSS value that activates drop zone highlighting. Defaults to "drop".
    property value : String = "drop"

    # Crystal-side callback fired on drop. Receives (x, y, paths).
    # Setting this also enables file drop — `enabled` does not need to be set separately.
    property on_drop : ((Int32, Int32, Array(String)) -> Nil)? = nil

    def initialize; end
  end

  # Window drag-handle options, configured via `opts.drag { |d| ... }`.
  #
  # ```
  # Lune.run(app) do |opts|
  #   opts.drag do |d|
  #     d.zone = "--lune-draggable"
  #   end
  # end
  # ```
  class DragOptions
    # CSS custom property name that marks an element as a window drag handle.
    # When non-empty, any element with this property set to `value` (and its
    # descendants) can be used to drag the window. Example: `"--lune-draggable"`.
    property zone : String = ""

    # CSS value that activates drag behaviour. Defaults to `"drag"`.
    property value : String = "drag"

    def initialize; end
  end

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
  class TrayOptions
    # Called when the tray icon is clicked (no menu attached).
    property on_click : (-> Nil)? = nil

    # Called when a tray context menu item is selected. Receives the item id.
    property on_menu_click : (String -> Nil)? = nil

    def initialize; end
  end

  # Configuration passed to `Lune.run` via its block parameter.
  #
  # ```
  # Lune.run(app) do |o|
  #   o.title  = "My App"
  #   o.width  = 1280
  #   o.height = 720
  #
  #   o.drop do |d|
  #     d.enabled = true
  #     d.zone    = "--lune-drop-target"
  #   end
  #
  #   o.mac do |m|
  #     m.full_size_content = true
  #   end
  # end
  # ```
  class Options
    # Window title bar text.
    property title : String = "Lune"

    # Initial window width in logical pixels.
    property width : Int32 = 1200

    # Initial window height in logical pixels.
    property height : Int32 = 800

    # Size constraint mode (NONE, MIN, MAX, FIXED). Ignored when `resizable` is false — the hint is forced to FIXED.
    property hint : Webview::SizeHints = Webview::SizeHints::NONE

    # When false the window cannot be resized by the user (forces `hint` to FIXED).
    property resizable : Bool = true

    # Minimum window width in logical pixels.
    property min_width : Int32? = nil

    # Minimum window height in logical pixels.
    property min_height : Int32? = nil

    # Maximum window width in logical pixels.
    property max_width : Int32? = nil

    # Maximum window height in logical pixels.
    property max_height : Int32? = nil

    # Enable webview debug/inspector tools.
    property debug : Bool = false

    # When true, suppresses the browser's default right-click context menu.
    property disable_context_menu : Bool = false

    # Called on every client-side navigation with the new URL as argument.
    # Fires on `popstate` and `hashchange` events.
    property on_navigate : (String -> Nil)? = nil

    # Called once after the webview window closes and the run loop exits.
    property on_close : (-> Nil)? = nil

    # Called once when the page's `load` event fires (i.e. the DOM is ready).
    property on_load : (-> Nil)? = nil

    # Called once immediately after the native window is created, before any
    # page navigation begins. Receives the platform-specific native window
    # handle (NSWindow* on macOS, GtkWindow* on Linux, HWND on Windows).
    property on_window_ready : (Void* -> Nil)? = nil

    getter drop : DropOptions = DropOptions.new
    getter drag : DragOptions = DragOptions.new
    getter tray : TrayOptions = TrayOptions.new
    getter mac  : MacOptions  = MacOptions.new

    def drop(& : DropOptions ->)
      yield @drop
    end

    def drag(& : DragOptions ->)
      yield @drag
    end

    def tray(& : TrayOptions ->)
      yield @tray
    end

    def mac(& : MacOptions ->)
      yield @mac
    end

    def initialize; end

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
