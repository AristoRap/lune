module Lune
  # Configuration passed to `Lune.run` via its block parameter.
  #
  # ```
  # Lune.run(app) do |o|
  #   o.title = "My App"
  #   o.width = 1280
  #   o.height = 720
  #
  #   o.file_drop do |fd|
  #     fd.zone = "--lune-drop-target"
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

    # Enable WebView devtools (right-click → Inspect). Use `{{ flag?(:lune_dev) }}` to auto-enable in dev.
    property devtools : Bool = false

    # When true, the window's last position and size are written to a JSON file
    # on close and restored on the next launch. Default `false` (opt-in) so
    # apps don't restore to off-screen coordinates if the user's monitor setup
    # changed between sessions. Suppressed in macOS menubar mode regardless,
    # since the window position there is derived from the tray icon.
    property remember_frame : Bool = false

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

    # Tray-only "popover" app mode: the window is hidden from the OS app
    # switcher (Dock on macOS, taskbar + Alt+Tab on Win32), starts hidden,
    # and auto-hides when the app loses focus. The tray icon shows at boot
    # automatically; pair with `opts.tray.toggle_window_on = [:left_click]`
    # for click-to-reveal popovers. Linux: not yet wired (no-op).
    property menubar_mode : Bool = false

    getter mac : Mac = Mac.new
    getter menu : Menu = Menu.new

    def mac(& : Mac ->)
      yield @mac
    end

    def menu(& : Menu ->)
      yield @menu
    end

    def menu(m : Menu)
      @menu = m
    end

    def initialize; end

    def apply(window : Config::Window)
      if t = window.title
        @title = t
      end
      if w = window.width
        @width = w
      end
      if h = window.height
        @height = h
      end
      if v = window.min_width
        @min_width = v
      end
      if v = window.min_height
        @min_height = v
      end
      if v = window.max_width
        @max_width = v
      end
      if v = window.max_height
        @max_height = v
      end
      unless (r = window.resizable).nil?
        @resizable = r
      end
      unless (d = window.devtools).nil?
        @devtools = d
      end
      unless (r = window.remember_frame).nil?
        @remember_frame = r
      end
    end
  end
end
