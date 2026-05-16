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

## All options

Properties are set via the `Lune::Options` block passed to `Lune.run`:

```crystal
Lune.run(app) do |opts|
  opts.title  = "My App"
  opts.width  = 1280
  opts.height = 720
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

### `on_tray_click`

**Type:** `(-> Nil)?` — **Default:** `nil`

Called when the system tray icon is clicked and no context menu is attached. See [Runtime Functions](./runtime#system-tray) for the full tray API.

```crystal
opts.on_tray_click = -> { app.emit("trayClick", nil) }
```

---

### `on_menu_click`

**Type:** `(String -> Nil)?` — **Default:** `nil`

Called when a tray context menu item is selected. Receives the item's `id`. See [Runtime Functions](./runtime#system-tray) for the full tray API.

```crystal
opts.on_menu_click = ->(id : String) { app.emit("trayMenuClick", id) }
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

## macOS menu bar

**Supported:** macOS — **Not applicable:** Linux, Windows

Lune automatically sets up a standard macOS menu bar when your app starts. No configuration required — it just works.

The default menu bar includes:

| Menu | Items |
| ---- | ----- |
| **[App name]** | About, Services, Hide / Hide Others / Show All, Quit (⌘Q) |
| **Edit** | Undo (⌘Z), Redo (⇧⌘Z), Cut, Copy, Paste, Select All |
| **Window** | Minimize (⌘M), Zoom, Bring All to Front |

The app name in the menu bar is taken from `opts.title` (or the `title` set in `lune.yml`).

> A user-configurable menu bar API (`app.menu { ... }`) is planned for a future release.

---

## macOS window appearance

**Supported:** macOS — **Not applicable:** Linux, Windows

macOS-specific options are grouped under `opts.mac` to keep them clearly separate from cross-platform settings.

```crystal
Lune.run(app, assets: "frontend/dist") do |opts|
  opts.mac.titlebar_transparent = true
  opts.mac.full_size_content    = true
  opts.mac.transparent          = true
  opts.mac.drag_zone            = "--lune-draggable"
end
```

### `mac.titlebar_transparent`

**Type:** `Bool` — **Default:** `false`

Makes the title bar background transparent. The window controls (traffic lights) remain visible. Usually paired with `full_size_content`.

```crystal
opts.mac.titlebar_transparent = true
```

---

### `mac.full_size_content`

**Type:** `Bool` — **Default:** `false`

Extends the content view to fill the entire window frame, including the area behind the title bar. Implies a transparent title bar — you do not need to set `titlebar_transparent` separately.

```crystal
opts.mac.full_size_content = true
```

> Use `padding-top` or `env(safe-area-inset-top)` in CSS to push content below the traffic lights when using this option.

---

### `mac.transparent`

**Type:** `Bool` — **Default:** `false`

Clears the window and WebView backgrounds so CSS `backdrop-filter` effects can sample whatever is behind the window — other windows, the desktop, etc. This is what produces the frosted-glass "mirror" look.

```crystal
opts.mac.transparent = true
```

```css
.sidebar {
  background: rgba(255, 255, 255, 0.08);
  backdrop-filter: blur(24px);
  -webkit-backdrop-filter: blur(24px);
}
```

> Without `backdrop-filter` in your CSS the window will appear fully transparent (see-through). Set a background colour on your root element when you only want the blur on specific regions.

---

### `mac.drag_zone` / `mac.drag_value`

**Types:** `String` — **Defaults:** `""` / `"drag"`

Enables CSS-driven drag zones. Set `drag_zone` to a CSS custom property name; any element (or its ancestors) that has that property set to `drag_value` becomes a handle for dragging the window. This is essential when using `full_size_content` without a native title bar.

```crystal
opts.mac.drag_zone  = "--lune-draggable"
opts.mac.drag_value = "drag"   # default — can be omitted
```

Then mark any element as a drag handle in CSS:

```css
.titlebar {
  --lune-draggable: drag;
}
```

Or inline:

```html
<div style="--lune-draggable: drag">...</div>
```

Drag detection walks up the DOM tree from the element under the cursor, so marking a container makes all its children draggable too.

---

### Full appearance example

```crystal
Lune.run(app, assets: "frontend/dist") do |opts|
  opts.title = "My App"

  opts.mac.full_size_content = true   # content under title bar (implies transparent title bar)
  opts.mac.transparent       = true   # clear background for backdrop-filter
  opts.mac.drag_zone         = "--lune-draggable"
end
```

```css
/* Mark the title bar as a drag zone — layout and styling are up to you */
.titlebar {
  --lune-draggable: drag;
}
```

---

## Full example

```crystal
Lune.run(app) do |opts|
  opts.title      = "Dashboard"
  opts.width      = 1280
  opts.height     = 800
  opts.min_width  = 900
  opts.min_height = 600
  opts.resizable  = true
  opts.debug      = {{ flag?(:debug) }}

  opts.mac.full_size_content = true
  opts.mac.transparent       = true
  opts.mac.drag_zone         = "--lune-draggable"

  opts.on_window_ready = ->(_handle : Void*) {
    puts "Window created"
  }

  opts.on_load = -> {
    app.emit("ready", nil)
  }

  opts.on_navigate = ->(url : String) {
    puts "Navigated to: #{url}"
  }

  opts.on_close = -> {
    cleanup()
  }
end
```
