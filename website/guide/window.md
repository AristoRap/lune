# Window Configuration

Window properties can be set in two places:

1. **`lune.yml`** — declare defaults for the project (shared via version control)
2. **The opts block in `Lune.run`** — override at the code level (takes priority)

```yaml
# lune.yml
window:
  title: My App
  width: 1440
  height: 900
```

```crystal
# src/main.cr — opts block overrides lune.yml values
Lune.run(app, assets: "frontend/dist") do |opts|
  opts.debug = true   # override just this one
end
```

If a property is set in both, the opts block wins. Properties not set in either use the built-in defaults.

---

## Window properties

Flat properties are set directly on `opts`. Grouped options use a nested block:

```crystal
Lune.run(app) do |opts|
  opts.title  = "My App"
  opts.width  = 1280
  opts.height = 720

  opts.drop do |d|
    d.enabled = true
    d.zone    = "--lune-drop-target"
  end

  opts.mac do |m|
    m.full_size_content = true
  end
end
```

---

### `title`

**Type:** `String` — **Default:** `"Lune"`

The text shown in the window title bar.

```crystal
opts.title = "My App"
```

---

### `width` / `height`

**Type:** `Int32` — **Defaults:** `1200` / `800`

Initial window dimensions in logical pixels (independent of screen DPI).

```crystal
opts.width  = 1440
opts.height = 900
```

---

### `resizable`

**Type:** `Bool` — **Default:** `true`

When `false`, the window cannot be resized by the user. Setting this to `false` also forces the size hint to `FIXED`.

```crystal
opts.resizable = false
```

---

### `min_width` / `min_height`

**Type:** `Int32?` — **Default:** `nil` (no constraint)

Minimum dimensions the user can resize the window to.

```crystal
opts.min_width  = 800
opts.min_height = 600
```

---

### `max_width` / `max_height`

**Type:** `Int32?` — **Default:** `nil` (no constraint)

Maximum dimensions the user can resize the window to.

```crystal
opts.max_width  = 1920
opts.max_height = 1080
```

---

### `debug`

**Type:** `Bool` — **Default:** `false`

When `true`, enables the WebView developer tools (right-click → Inspect on macOS/Linux). Useful during development.

```crystal
opts.debug = true
```

You can wire this to a compile-time flag so it's only active in dev builds:

```crystal
opts.debug = {{ flag?(:debug) }}
```

---

### `disable_context_menu`

**Type:** `Bool` — **Default:** `false`

When `true`, suppresses the browser's built-in right-click context menu (the one with "Inspect Element", "Copy Image", etc.). Use this when you want full control over right-click behaviour in your app.

```crystal
opts.disable_context_menu = true
```

---

## Lifecycle callbacks

### `on_window_ready`

**Type:** `(Void* -> Nil)?` — **Default:** `nil`

Called once immediately after the native window is created, before any page navigation begins. The webview exists and bindings are registered, but no content has loaded yet. Use this for one-time Crystal-side setup that must happen before the first page render. The callback receives the native window handle as a `Void*`.

```crystal
opts.on_window_ready = ->(_handle : Void*) {
  puts "Window open, about to navigate"
}
```

> **vs `on_load`:** `on_window_ready` fires on the Crystal side as soon as the native window is alive. `on_load` fires later, after the frontend page's `load` event — i.e. once the DOM is fully ready. Use `on_window_ready` for setup work that should not wait for the frontend; use `on_load` to interact with the frontend.

---

### `on_load`

**Type:** `(-> Nil)?` — **Default:** `nil`

Called once when the page's `load` event fires — i.e. the DOM is fully ready. Use this to run Crystal code that depends on the frontend being initialized.

```crystal
opts.on_load = -> {
  puts "Frontend ready"
  app.emit("init", { "version" => "1.0.0" })
}
```

---

### `on_navigate`

**Type:** `(String -> Nil)?` — **Default:** `nil`

Called on every client-side navigation with the new URL as argument. Fires on `popstate` and `hashchange` events. Useful for tracking routing in a single-page app or for applying access control.

```crystal
opts.on_navigate = ->(url : String) {
  puts "Navigated to: #{url}"
}
```

---

### `on_close`

**Type:** `(-> Nil)?` — **Default:** `nil`

Called once when the window is closed and the run loop exits. Use this for cleanup — closing database connections, flushing logs, etc.

```crystal
opts.on_close = -> {
  db.close
  puts "App closed"
}
```

---

## Window state persistence

Lune automatically saves and restores the window's position and size. No configuration required — it just works.

When the window closes, the current frame is written to a JSON file. On the next launch, that file is read and the window is restored to the same position and size before the page loads.

### Storage location

The state file is stored under the app's config directory, derived from the window `title`:

| Platform | Path                                                                           |
| -------- | ------------------------------------------------------------------------------ |
| macOS    | `~/Library/Application Support/<appname>/window.json`                          |
| Linux    | `$XDG_CONFIG_HOME/<appname>/window.json` (falls back to `~/.config/<appname>`) |

`<appname>` is derived from `opts.title` — lowercased, spaces replaced with hyphens, non-alphanumeric characters removed. For example, `"My App"` → `my-app`.

### First launch

On the first launch no file exists yet, so the window opens at the size and position specified by `opts.width` / `opts.height` (or the `lune.yml` defaults). After the window is closed for the first time, persistence kicks in on every subsequent launch.

### Example

```crystal
Lune.run(app) do |opts|
  opts.title  = "My App"   # → stored at .../my-app/window.json
  opts.width  = 1280
  opts.height = 800
end
```

After the user resizes and moves the window, the next launch will reopen it at exactly the same position and size, regardless of what `opts.width` and `opts.height` say.

---

## File drop

Lune provides a complete drag-and-drop file API: a boolean to enable native drops, separate control to suppress the WebView's built-in drag handling, CSS-based drop zones for per-element highlighting, and JS helpers for subscribing to drops.

File drop options are configured in an `opts.drop` block:

```crystal
opts.drop do |d|
  d.enabled = true
  d.zone    = "--lune-drop-target"
  d.on_drop = ->(x : Int32, y : Int32, paths : Array(String)) {
    puts "Dropped #{paths.size} file(s)"
  }
end
```

### `drop.enabled`

**Type:** `Bool` — **Default:** `false`

When `true`, registers the window as a native drop target. The WebView's own drag handling is automatically disabled so dropped files don't open or navigate. The `fileDrop` event is emitted to the frontend on every drop.

---

### `drop.disable_webview_drop`

**Type:** `Bool` — **Default:** `false`

Disables the WebView's built-in drag handling without setting up a drop target. Prevents files from accidentally opening or navigating inside the WebView when `drop.enabled` is not needed.

---

### `drop.zone` / `drop.value`

**Type:** `String` — **Defaults:** `""` / `"drop"`

Mark specific elements as drop targets using a CSS custom property. Set `zone` to a CSS custom property name; any element with that property equal to `value` gets the class `lune-drop-target-active` while a file is dragged over it.

```crystal
opts.drop do |d|
  d.enabled = true
  d.zone    = "--lune-drop-target"
  d.value   = "drop"   # default — can be omitted
end
```

```css
.upload-area {
  --lune-drop-target: drop;
}

.upload-area.lune-drop-target-active {
  border: 2px dashed #007aff;
  background: rgba(0, 122, 255, 0.08);
}
```

Requires `enabled = true`. The `lune-drop-target-active` class is added and removed in real time as the pointer moves.

---

### `drop.on_drop`

**Type:** `((Int32, Int32, Array(String)) -> Nil)?` — **Default:** `nil`

Crystal-side callback fired when the user drops files. Receives the drop position in logical pixels and an array of absolute file paths. Setting this callback also enables file drop automatically — `enabled` does not need to be set separately.

```crystal
opts.drop do |d|
  d.on_drop = ->(x : Int32, y : Int32, paths : Array(String)) {
    puts "Dropped #{paths.size} file(s) at (#{x}, #{y})"
    app.emit("fileDrop", {"x" => x, "y" => y, "paths" => paths})
  }
end
```

---

### JS helpers — `onFileDrop` / `onFileDropOff`

Convenience wrappers around the event bus for subscribing to file drops from the frontend.

```js
import { onFileDrop, onFileDropOff } from "../lunejs/runtime/runtime.js";

onFileDrop((x, y, paths) => {
  console.log("Dropped at", x, y, paths);
});

// later — unsubscribe all drop listeners
onFileDropOff();
```

TypeScript signature:

```ts
declare function onFileDrop(
  cb: (x: number, y: number, paths: string[]) => void,
): void;
declare function onFileDropOff(): void;
```

These are shorthand for `on("fileDrop", ...)` / `off("fileDrop")` — you can also use the generic event bus directly if you prefer.

---

### Full file drop example

```crystal
Lune.run(app, assets: "frontend/dist") do |opts|
  opts.drop do |d|
    d.enabled = true
    d.zone    = "--lune-drop-target"
    d.on_drop = ->(x : Int32, y : Int32, paths : Array(String)) {
      puts "Dropped: #{paths.inspect}"
    }
  end
end
```

```css
.drop-area {
  --lune-drop-target: drop;
  border: 2px dashed transparent;
  transition: border-color 0.15s;
}

.drop-area.lune-drop-target-active {
  border-color: #007aff;
}
```

```js
import { onFileDrop } from "../lunejs/runtime/runtime.js";

onFileDrop((x, y, paths) => {
  paths.forEach((p) => console.log("File:", p));
});
```

---

## Tray

Tray callbacks are configured in an `opts.tray` block. See [Runtime Functions](./runtime#system-tray) for the full tray API.

```crystal
opts.tray do |t|
  t.on_click      = -> { app.emit("trayClick", nil) }
  t.on_menu_click = ->(id : String) { app.emit("trayMenuClick", id) }
end
```

### `tray.on_click`

**Type:** `(-> Nil)?` — **Default:** `nil`

Called when the system tray icon is clicked and no context menu is active.

---

### `tray.on_menu_click`

**Type:** `(String -> Nil)?` — **Default:** `nil`

Called when a tray context menu item is selected. Receives the item's `id`.

---

## macOS

**Supported:** macOS — **Not applicable:** Linux, Windows

### Menu bar

Use `opts.menu { |m| }` to define the application menu bar. When no menu is configured, Lune falls back to a standard menu (App + Edit + Window menus). If you set `opts.menu`, that menu replaces the default entirely.

```crystal
opts.menu do |m|
  m.app_menu   # standard macOS app menu (About, Services, Hide, Quit)

  m.submenu "File" do |file|
    file.item "New",  shortcut: "cmd+n" do create_document end
    file.item "Open", shortcut: "cmd+o" do open_dialog end
    file.separator
    file.item "Quit", shortcut: "cmd+q" do app.eval("runtime.quit()") end
  end

  m.edit_menu  # standard macOS edit menu (Undo, Redo, Cut, Copy, Paste, Select All)

  m.submenu "View" do |view|
    view.checkbox "Dark Mode", shortcut: "cmd+shift+d" do |on|
      app.eval("document.body.classList.toggle('dark', #{on})")
    end
  end
end
```

#### Role menus

Role menus insert the standard macOS menus built from native selectors — they work correctly without any Crystal callbacks.

| Method        | Inserts                                                             |
| ------------- | ------------------------------------------------------------------- |
| `m.app_menu`  | App menu: About, Services, Hide / Hide Others / Show All, Quit (⌘Q) |
| `m.edit_menu` | Edit menu: Undo (⌘Z), Redo (⇧⌘Z), Cut, Copy, Paste, Select All      |

Per macOS convention `m.app_menu` should be first. `m.edit_menu` makes text inputs in your WebView support undo/redo and clipboard shortcuts automatically.

#### Submenus

`m.submenu(label) { |group| }` adds a top-level menu. Inside the block, call builder methods on `group`:

| Method                                                  | Description                                  |
| ------------------------------------------------------- | -------------------------------------------- |
| `group.item(label, shortcut:, enabled:) { }`            | Clickable text item                          |
| `group.separator`                                       | Horizontal separator line                    |
| `group.checkbox(label, checked:, shortcut:) { \|on\| }` | Toggle item; block receives new `Bool` state |
| `group.radio(label, selected:, shortcut:) { }`          | Radio item; adjacent radio items auto-group  |
| `group.submenu(label) { \|sub\| }`                      | Nested submenu                               |

All builder methods return the `Options::Menu::Item` they create — hold the reference to mutate it later (see [Runtime updates](#runtime-updates)).

#### Shortcuts

Pass a shortcut string to any item. The format is modifier tokens joined by `+`, with the key last:

```
"cmd+n"          # ⌘N
"cmd+shift+z"    # ⇧⌘Z
"cmd+opt+t"      # ⌥⌘T
"ctrl+opt+a"     # ⌃⌥A
"cmd+f1"         # ⌘F1
"cmd+return"     # ⌘↩
"cmd+delete"     # ⌘⌫
```

| Token                    | Modifier  |
| ------------------------ | --------- |
| `cmd` / `command`        | ⌘ Command |
| `shift`                  | ⇧ Shift   |
| `opt` / `alt` / `option` | ⌥ Option  |
| `ctrl` / `control`       | ⌃ Control |

Named keys: `return`, `enter`, `tab`, `escape` / `esc`, `delete` / `backspace`, `space`, `up`, `down`, `left`, `right`, `home`, `end`, `pageup`, `pagedown`, `f1`–`f12`.

Single-letter keys are automatically uppercased when `shift` is present (`"cmd+shift+z"` → key `Z`).

#### Checkbox items

The block receives the new checked state as a `Bool`. The visual checkmark is toggled automatically by the native layer.

```crystal
m.submenu "View" do |view|
  view.checkbox "Show Sidebar", checked: true, shortcut: "cmd+\\" do |on|
    app.emit("sidebar", on)
  end
end
```

#### Radio items

Adjacent radio items form a group automatically — no explicit grouping needed. When one is selected, the others in the group are deselected by the native layer. The block fires for the newly selected item only.

```crystal
m.submenu "Appearance" do |a|
  a.radio "System", selected: true do apply_theme(:system) end
  a.radio "Light"                  do apply_theme(:light) end
  a.radio "Dark"                   do apply_theme(:dark) end
end
```

To have two independent radio groups in the same submenu, separate them with a `separator`.

#### Runtime updates

Every builder method returns the `Options::Menu::Item` it creates. Hold a reference to mutate `label`, `enabled`, or `checked` at runtime, then call `app.update_menu` to push the changes to the native layer.

```crystal
pause_item : Lune::Options::Menu::Item? = nil

opts.menu do |m|
  m.submenu "File" do |file|
    pause_item = file.item("Pause", shortcut: "cmd+p") do
      paused = !paused
      pause_item.not_nil!.label = paused ? "Resume" : "Pause"
      app.update_menu
    end
  end
end
```

To replace the entire menu bar at runtime:

```crystal
app.set_menu do |m|
  m.app_menu
  m.submenu "File" do |file|
    file.item("Quit") { app.eval("runtime.quit()") }
  end
end
```

Both `app.update_menu` and `app.set_menu` are no-ops on non-macOS platforms.

#### Class-based menus

For larger apps, subclass `Options::Menu::Group` or `Options::Menu` instead of using inline blocks. The builder methods (`item`, `separator`, `checkbox`, `radio`, `submenu`) are inherited and can be called directly in `initialize`. State and callbacks live inside the class, keeping `main.cr` clean.

```crystal
class FileMenu < Lune::Options::Menu::Group
  @pause_item : Lune::Options::Menu::Item? = nil
  getter clock_paused : Bool = false

  def initialize(@app : Lune::App)
    super("File")
    @pause_item = item("Pause Clock", shortcut: "cmd+p") { toggle_clock }
    separator
    item("Quit", shortcut: "cmd+q") { @app.eval("runtime.quit()") }
  end

  private def toggle_clock
    @clock_paused = !@clock_paused
    @pause_item.not_nil!.label = @clock_paused ? "Resume Clock" : "Pause Clock"
    @app.update_menu
  end
end
```

Pass an instance directly to `submenu` — no block needed:

```crystal
opts.menu do |m|
  m.app_menu
  m.submenu FileMenu.new(app)   # class-based
  m.edit_menu
  m.submenu "View" do |view|    # inline block also works
    view.item("Zoom In") { app.eval("...") }
  end
end
```

To subclass the top-level menu itself:

```crystal
class AppMenu < Lune::Options::Menu
  def initialize(app : Lune::App)
    super()
    app_menu
    submenu FileMenu.new(app)
    edit_menu
  end
end

opts.menu AppMenu.new(app)
```

---

### Window drag zones

Set `drag.zone` to a CSS custom property name and any element with that property set to `drag.value` becomes a handle for dragging the window. Essential when using a custom title bar without the native one.

```crystal
opts.drag do |d|
  d.zone  = "--lune-draggable"
  d.value = "drag"   # default — can be omitted
end
```

Then mark any element as a drag handle:

```css
.titlebar {
  --lune-draggable: drag;
}
```

Or inline:

```html
<div style="--lune-draggable: drag">...</div>
```

Drag detection walks up the DOM tree, so marking a container makes all its children draggable too.

---

### Window appearance

macOS-specific options are configured in an `opts.mac` block:

```crystal
opts.mac do |m|
  m.full_size_content = true
  m.transparent       = true
  m.appearance        = Lune::Options::Mac::Appearance::Dark
end
```

#### `mac.full_size_content`

**Type:** `Bool` — **Default:** `false`

Extends the content view to fill the entire window frame including the area behind the title bar, and makes the title bar itself transparent. The window controls (traffic lights) remain visible.

> Use `padding-top` in CSS to push content below the traffic lights when using this option.

---

#### `mac.transparent`

**Type:** `Bool` — **Default:** `false`

Clears the window and WebView backgrounds so CSS `backdrop-filter` effects can sample whatever is behind the window — other windows, the desktop, etc. This is what produces the frosted-glass "mirror" look.

```css
.sidebar {
  background: rgba(255, 255, 255, 0.08);
  backdrop-filter: blur(24px);
  -webkit-backdrop-filter: blur(24px);
}
```

> Without `backdrop-filter` in your CSS the window will appear fully transparent (see-through). Set a background colour on your root element when you only want the blur on specific regions.

---

#### `mac.hide_title`

**Type:** `Bool` — **Default:** `false`

Hides the window title text while keeping the title bar (and traffic lights) visible. Commonly combined with `full_size_content` for a clean custom header where the traffic lights float over your content.

---

#### `mac.appearance`

**Type:** `Lune::Options::Mac::Appearance` — **Default:** `Auto`

Forces a specific appearance mode for the window regardless of the system setting.

| Value                  | Effect                                          |
| ---------------------- | ----------------------------------------------- |
| `Mac::Appearance::Auto`  | Follows the system dark/light setting (default) |
| `Mac::Appearance::Dark`  | Forces dark mode                                |
| `Mac::Appearance::Light` | Forces light mode                               |

---

#### `mac.content_protection`

**Type:** `Bool` — **Default:** `false`

Prevents the window content from appearing in screenshots, screen recordings, or screen sharing. The window shows as a black rectangle to capturing software.

---

#### `mac.always_on_top`

**Type:** `Bool` — **Default:** `false`

Keeps the window above all other windows, including those from other apps. Useful for utility apps, overlays, and floating toolbars.

---

#### Full appearance example

```crystal
Lune.run(app, assets: "frontend/dist") do |opts|
  opts.title = "My App"

  opts.drag do |d|
    d.zone = "--lune-draggable"
  end

  opts.mac do |m|
    m.full_size_content = true
    m.transparent       = true
    m.hide_title        = true
    m.appearance        = Lune::Options::Mac::Appearance::Dark
  end
end
```

---

## Full example

```crystal
# Class-based submenu — state and callbacks live in the class.
class FileMenu < Lune::Options::Menu::Group
  @pause_item : Lune::Options::Menu::Item? = nil
  getter clock_paused : Bool = false

  def initialize(@app : Lune::App)
    super("File")
    @pause_item = item("Pause Clock", shortcut: "cmd+p") { toggle_clock }
    separator
    item("Reload", shortcut: "cmd+r") { @app.eval("location.reload()") }
    separator
    item("Quit",   shortcut: "cmd+q") { @app.eval("runtime.quit()") }
  end

  private def toggle_clock
    @clock_paused = !@clock_paused
    @pause_item.not_nil!.label = @clock_paused ? "Resume Clock" : "Pause Clock"
    @app.update_menu
    @app.emit("clockPaused", @clock_paused)
  end
end

app = Lune::App.new
file_menu = FileMenu.new(app)

Lune.run(app) do |opts|
  opts.title               = "Dashboard"
  opts.width               = 1280
  opts.height              = 800
  opts.min_width           = 900
  opts.min_height          = 600
  opts.resizable           = true
  opts.disable_context_menu = true
  opts.debug               = {{ flag?(:debug) }}

  opts.drop do |d|
    d.enabled = true
    d.zone    = "--lune-drop-target"
    d.on_drop = ->(x : Int32, y : Int32, paths : Array(String)) {
      app.emit("fileDrop", {"x" => x, "y" => y, "paths" => paths})
    }
  end

  opts.drag do |d|
    d.zone = "--lune-draggable"
  end

  opts.tray do |t|
    t.on_click      = -> { app.emit("trayClick", nil) }
    t.on_menu_click = ->(id : String) { app.emit("trayMenuClick", id) }
  end

  opts.menu do |m|
    m.app_menu
    m.submenu file_menu              # class-based Group
    m.edit_menu
    m.submenu "View" do |view|       # inline block
      view.item("Zoom In")      { app.eval("document.body.style.zoom = String(Math.round((parseFloat(document.body.style.zoom||'1')+0.1)*10)/10)") }
      view.item("Zoom Out")     { app.eval("document.body.style.zoom = String(Math.round((Math.max(0.5,parseFloat(document.body.style.zoom||'1')-0.1))*10)/10)") }
      view.item("Actual Size",  shortcut: "cmd+0") { app.eval("document.body.style.zoom='1'") }
    end
  end

  opts.mac do |m|
    m.full_size_content = true
    m.transparent       = true
    m.hide_title        = true
  end

  opts.on_window_ready = ->(_handle : Void*) { app.emit("windowReady", nil) }
  opts.on_load         = -> { app.emit("ready", nil) }
  opts.on_navigate     = ->(url : String) { puts "navigated: #{url}" }
  opts.on_close        = -> { puts "closed" }
end
```
