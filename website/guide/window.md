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
declare function onFileDrop(cb: (x: number, y: number, paths: string[]) => void): void;
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

## Tray callbacks

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

| Menu           | Items                                                     |
| -------------- | --------------------------------------------------------- |
| **[App name]** | About, Services, Hide / Hide Others / Show All, Quit (⌘Q) |
| **Edit**       | Undo (⌘Z), Redo (⇧⌘Z), Cut, Copy, Paste, Select All       |
| **Window**     | Minimize (⌘M), Zoom, Bring All to Front                   |

The app name in the menu bar is taken from `opts.title` (or the `title` set in `lune.yml`).

> A user-configurable menu bar API (`app.menu { ... }`) is planned for a future release.

---

## Window drag zones

CSS custom property-based drag handles — macOS implementation.

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

## macOS window appearance

**Supported:** macOS — **Not applicable:** Linux, Windows

macOS-specific options are configured in an `opts.mac` block:

```crystal
opts.mac do |m|
  m.full_size_content = true
  m.transparent       = true
  m.appearance        = Lune::MacAppearance::Dark
end
```

### `mac.full_size_content`

**Type:** `Bool` — **Default:** `false`

Extends the content view to fill the entire window frame including the area behind the title bar, and makes the title bar itself transparent. The window controls (traffic lights) remain visible.

> Use `padding-top` in CSS to push content below the traffic lights when using this option.

---

### `mac.transparent`

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

### `mac.hide_title`

**Type:** `Bool` — **Default:** `false`

Hides the window title text while keeping the title bar (and traffic lights) visible. Commonly combined with `full_size_content` for a clean custom header where the traffic lights float over your content.

---

### `mac.appearance`

**Type:** `Lune::MacAppearance` — **Default:** `Auto`

Forces a specific appearance mode for the window regardless of the system setting.

| Value                  | Effect                                          |
| ---------------------- | ----------------------------------------------- |
| `MacAppearance::Auto`  | Follows the system dark/light setting (default) |
| `MacAppearance::Dark`  | Forces dark mode                                |
| `MacAppearance::Light` | Forces light mode                               |

---

### `mac.content_protection`

**Type:** `Bool` — **Default:** `false`

Prevents the window content from appearing in screenshots, screen recordings, or screen sharing. The window shows as a black rectangle to capturing software.

---

### `mac.always_on_top`

**Type:** `Bool` — **Default:** `false`

Keeps the window above all other windows, including those from other apps. Useful for utility apps, overlays, and floating toolbars.

---

### Full appearance example

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
    m.appearance        = Lune::MacAppearance::Dark
  end
end
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

  opts.drag do |d|
    d.zone = "--lune-draggable"
  end

  opts.drop do |d|
    d.enabled = true
    d.on_drop = ->(x : Int32, y : Int32, paths : Array(String)) {
      app.emit("fileDrop", {"x" => x, "y" => y, "paths" => paths})
    }
  end

  opts.tray do |t|
    t.on_click      = -> { app.emit("trayClick", nil) }
    t.on_menu_click = ->(id : String) { app.emit("trayMenuClick", id) }
  end

  opts.mac do |m|
    m.full_size_content = true
    m.transparent       = true
    m.hide_title        = true
  end

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
