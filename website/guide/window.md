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
  opts.devtools = true   # override just this one
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

  opts.file_drop do |fd|
    fd.zone = "--lune-drop-target"
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

### `devtools`

**Type:** `Bool` — **Default:** `false`

Enables the WebView developer tools panel (right-click → Inspect on macOS/Linux). This is the **WebView inspector** — it is unrelated to the CLI `--debug` flag, which controls verbose runtime logging.

Use the built-in `:lune_dev` compile flag so it's on during `lune dev` and automatically off in production — no manual wiring needed:

```crystal
opts.devtools = {{ flag?(:lune_dev) }}
```

`lune dev` passes `-Dlune_dev` to the compiler automatically. `lune build` does not, so the expression evaluates to `false` in production builds.

---

### Block the default context menu

The ContextMenu plugin owns this — set `opts.context_menu.block_default = true` to suppress the browser's built-in right-click menu (the one with "Inspect Element", "Copy Image", etc.). Use when you want full control over right-click behaviour in your app.

```crystal
opts.context_menu.block_default = true
```

> To show a **native** context menu on right-click instead, use [`setContextMenu`](./runtime#context-menus) from JavaScript — `setContextMenu` intercepts `contextmenu` automatically, so `block_default` is not needed alongside it.

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
  app.events.emit("init", { "version" => "1.0.0" })
}
```

---

### `on_navigate`

**Type:** `(String -> Nil)?` — **Default:** `nil`

Called on every client-side navigation with the new URL as argument. Fires on `popstate`, `hashchange`, and (via a `history.pushState` / `replaceState` shim) every SPA-router navigation — React Router, Vue Router, Next client transitions, etc.

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

Lune can save and restore the window's position and size between launches. Opt-in via `opts.remember_frame = true` — the default is `false` so apps don't end up restoring to off-screen coordinates if the user's monitor setup changed between sessions.

When the window closes (or, on Windows, on a 500 ms tracker while it's alive), the current frame is written to a JSON file. On the next launch, that file is read and the window is restored to the same position and size before the page loads.

### `opts.remember_frame`

**Type:** `Bool` — **Default:** `false`

```crystal
Lune.run(app) do |opts|
  opts.remember_frame = true
end
```

Or in `lune.yml`:

```yaml
window:
  remember_frame: true
```

When `false` (the default), Lune ignores any previously saved state and opens the window at `opts.width` / `opts.height` every launch. On macOS in menubar mode (`mac.menubar_mode = true`), persistence is always disabled regardless of this flag — the window position there is derived from the tray icon on each toggle.

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
  opts.title           = "My App"   # → stored at .../my-app/window.json
  opts.width           = 1280
  opts.height          = 800
  opts.remember_frame  = true
end
```

After the user resizes and moves the window, the next launch will reopen it at exactly the same position and size, regardless of what `opts.width` and `opts.height` say.

---

## File drop

Lune provides a complete drag-and-drop file API: CSS-based drop zones for per-element highlighting, a Crystal callback, and JS helpers for subscribing to drops.

Enable the `file_drop` plugin in `lune.yml` to activate native drop handling. Options in `opts.file_drop` configure its behaviour.

```crystal
opts.file_drop do |fd|
  fd.zone    = "--lune-drop-target"
  fd.on_drop = ->(x : Int32, y : Int32, paths : Array(String)) {
    puts "Dropped #{paths.size} file(s)"
  }
end
```

### `file_drop.disable_webview_drop`

**Type:** `Bool` — **Default:** `false`

Disables the WebView's built-in drag handling globally, without enabling the `file_drop` plugin. Prevents files from accidentally opening or navigating inside the WebView.

---

### `file_drop.zone` / `file_drop.value`

**Type:** `String` — **Defaults:** `""` / `"drop"`

Mark specific elements as drop targets using a CSS custom property. Set `zone` to a CSS custom property name; any element with that property set **inline** and equal to `value` gets the class `lune-drop-target-active` while a file is dragged over it.

> **Inline style required.** The property must be set as an inline style (`style="--lune-drop-target: drop"`), not via a CSS class. Zone detection reads `el.style` directly to avoid matching child elements that would otherwise inherit the value.

```crystal
opts.file_drop do |fd|
  fd.zone  = "--lune-drop-target"
  fd.value = "drop"   # default — can be omitted
end
```

```html
<div class="upload-area" style="--lune-drop-target: drop">Drop files here</div>
```

```css
.upload-area.lune-drop-target-active {
  border: 2px dashed #007aff;
  background: rgba(0, 122, 255, 0.08);
}
```

Requires the `file_drop` plugin to be active. The `lune-drop-target-active` class is added and removed in real time as the pointer moves.

---

### `file_drop.on_drop`

**Type:** `((Int32, Int32, Array(String)) -> Nil)?` — **Default:** `nil`

Crystal-side callback fired when the user drops files. Receives the drop position in logical pixels and an array of absolute file paths. Requires the `file_drop` plugin to be active in `lune.yml`.

```crystal
opts.file_drop do |fd|
  fd.on_drop = ->(x : Int32, y : Int32, paths : Array(String)) {
    puts "Dropped #{paths.size} file(s) at (#{x}, #{y})"
    app.events.emit("fileDrop", {"x" => x, "y" => y, "paths" => paths})
  }
end
```

---

### JS helpers — `lune.FileDrop.on` / `lune.FileDrop.off`

Convenience wrappers around the event bus for subscribing to file drops from the frontend.

```js
import { lune } from "../lunejs/runtime/runtime.js";

lune.FileDrop.on((x, y, paths) => {
  console.log("Dropped at", x, y, paths);
});

// later — unsubscribe
lune.FileDrop.off();
```

TypeScript signature:

```ts
lune.FileDrop.on(cb: (x: number, y: number, paths: string[]) => void): void;
lune.FileDrop.off(): void;
```

---

### Full file drop example

```crystal
Lune.run(app, assets: "frontend/dist") do |opts|
  opts.file_drop do |fd|
    fd.zone    = "--lune-drop-target"
    fd.on_drop = ->(x : Int32, y : Int32, paths : Array(String)) {
      puts "Dropped: #{paths.inspect}"
    }
  end
end
```

```html
<div class="drop-area" style="--lune-drop-target: drop">Drop files here</div>
```

```css
.drop-area {
  border: 2px dashed transparent;
  transition: border-color 0.15s;
}

.drop-area.lune-drop-target-active {
  border-color: #007aff;
}
```

```js
import { lune } from "../lunejs/runtime/runtime.js";

lune.FileDrop.on((x, y, paths) => {
  paths.forEach((p) => console.log("File:", p));
});
```

---

## Tray

Tray events are emitted automatically on the event bus — no `opts.tray` block required. See [Runtime Functions](./runtime#system-tray) for the full JS API.

By default the event name is `"trayEvent"`. Both tray icon clicks (`"click"`) and menu item selections (item `id`) are emitted under the same event name.

```js
import { lune } from "../lunejs/runtime/runtime.js";

lune.Events.on("trayEvent", (payload) => {
  if (payload === "click") console.log("icon clicked");
  else console.log("menu item:", payload);
});
```

### `tray.event`

**Type:** `String` — **Default:** `"trayEvent"`

The event bus name for tray activity. Override it if you want a different name or separate click vs menu events via two names.

```crystal
opts.tray do |t|
  t.event = "myTray"
end
```

---

### `tray.on_click` _(advanced override)_

**Type:** `(-> Nil)?` — **Default:** `nil`

When set, replaces the default `app.events.emit` for tray icon clicks entirely. Use when you need Crystal-side side-effects beyond event emission.

---

### `tray.on_menu_click` _(advanced override)_

**Type:** `(String -> Nil)?` — **Default:** `nil`

When set, replaces the default `app.events.emit` for menu item selection entirely. Receives the item's `id`.

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
    app.events.emit("sidebar", on)
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

### Window drag zones _(macOS only)_

Set `drag.zone` to a CSS custom property name and any element with that property set to `drag.value` becomes a handle for dragging the window. Essential when using a custom title bar without the native one.

```crystal
opts.window_drag do |d|
  d.zone  = "--lune-draggable"
  d.value = "drag"   # default — can be omitted
end
```

> **Inline style required.** The property must be set as `style="--lune-draggable: true"`, not via a CSS class, so that detection does not match child elements that inherit the value.

Mark any element as a drag handle using an inline style:

```html
<div style="--lune-draggable: true">...</div>
```

Drag detection walks up the DOM tree, so marking a container makes all its children draggable too.

> **Platform support.** macOS only — `drag.zone` silently no-ops on Linux and Windows. Tracked on the [roadmap](https://github.com/AristoRap/lune/blob/main/ROADMAP.md).

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

#### `mac.hide_traffic_lights`

**Type:** `Bool` — **Default:** `false`

Hides the close, minimise, and zoom buttons (the traffic lights). Combined with `full_size_content`, `hide_title`, and CSS drag zones, this gives you a fully chrome-free window with completely custom UI.

```crystal
opts.mac do |m|
  m.full_size_content   = true
  m.hide_title          = true
  m.hide_traffic_lights = true
end
```

> Remember to provide your own close/minimise controls in your frontend when using this option — the user will have no OS-level way to close the window otherwise.

---

#### `mac.appearance`

**Type:** `Lune::Options::Mac::Appearance` — **Default:** `Auto`

Forces a specific appearance mode for the window regardless of the system setting.

| Value                    | Effect                                          |
| ------------------------ | ----------------------------------------------- |
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

  opts.window_drag do |d|
    d.zone = "--lune-draggable"
  end

  opts.mac do |m|
    m.full_size_content   = true
    m.transparent         = true
    m.hide_title          = true
    m.hide_traffic_lights = true
    m.appearance          = Lune::Options::Mac::Appearance::Dark
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
    @app.events.emit("clockPaused", @clock_paused)
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
  opts.context_menu.block_default = true
  opts.devtools                   = {{ flag?(:lune_dev) }}

  opts.file_drop do |fd|
    fd.zone    = "--lune-drop-target"
    fd.on_drop = ->(x : Int32, y : Int32, paths : Array(String)) {
      app.events.emit("file_drop", {"x" => x, "y" => y, "paths" => paths})
    }
  end

  opts.window_drag do |d|
    d.zone = "--lune-draggable"
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

  opts.on_window_ready = ->(_handle : Void*) { app.events.emit("windowReady", nil) }
  opts.on_load         = -> { app.events.emit("ready", nil) }
  opts.on_navigate     = ->(url : String) { puts "navigated: #{url}" }
  opts.on_close        = -> { puts "closed" }
end
```
