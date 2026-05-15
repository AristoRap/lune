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
