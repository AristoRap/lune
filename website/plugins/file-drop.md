# FileDrop

> Accept files dragged onto the app window from the OS.

|                  |                                  |
| ---------------- | -------------------------------- |
| **Config key**   | `file_drop`                      |
| **JS namespace** | `FileDrop`                       |
| **Core**         | No                               |
| **Phases**       | WebviewInject                    |
| **Hard deps**    | `events`                         |
| **Platforms**    | macOS · Linux (Windows: planned) |

FileDrop intercepts native OS file-drop events and delivers them to JavaScript as `{ x, y, paths }` events on the event bus.

Disabling `events` automatically disables this plugin.

---

## Enabling

```yaml
plugins:
  enabled:
    - file_drop
    - events # required
```

Or omit `plugins:` entirely.

---

## Basic usage

Listen for drops anywhere in the window:

```js
import { lune } from "../lunejs/runtime/runtime.js";

lune.FileDrop.on((x, y, paths) => {
  console.log("Dropped at", x, y, paths);
});

lune.FileDrop.off(); // stop listening
```

---

## Drop zones

Mark elements as drop targets with a custom CSS property:

```crystal
Lune.run(app) do |opts|
  opts.file_drop do |fd|
    fd.zone  = "--lune-drop-target"   # CSS custom property name
    fd.value = "true"                  # expected value
  end
end
```

```css
.my-dropzone {
  --lune-drop-target: true;
}
```

When a drop zone is active, only drops that land on a matching element fire the event. The element gains a `lune-drop-target-active` class while the user is dragging over it.

---

## Crystal options

Configure in `Lune.run`:

```crystal
Lune.run(app) do |opts|
  opts.file_drop do |fd|
    fd.zone  = "--lune-drop-target"
    fd.value = "true"

    # Optional Crystal-side callback (runs before JS receives the event)
    fd.on_drop = ->(x : Int32, y : Int32, paths : Array(String)) {
      puts "Dropped: #{paths}"
    }
  end
end
```

| Option                 | Type                                   | Description                                                     |
| ---------------------- | -------------------------------------- | --------------------------------------------------------------- |
| `zone`                 | `String`                               | CSS custom property name that marks drop targets                |
| `value`                | `String`                               | Expected value for the CSS property                             |
| `on_drop`              | `(Int32, Int32, Array(String)) -> Nil` | Crystal callback called on every drop                           |
| `disable_webview_drop` | `Bool`                                 | Prevent the WebView's own drag-drop handling (default: enabled) |

---

## JavaScript API

| Method | Signature | Description                                        |
| ------ | --------- | -------------------------------------------------- |
| `on`   | `on(cb)`  | Persistent listener; `cb` receives `(x, y, paths)` |
| `off`  | `off()`   | Remove all listeners                               |

---

## Windows behaviour

The plugin is auto-filtered from the registry on Windows (Win32 needs `OleInitialize` + `RegisterDragDrop` plumbing — tracked in [ROADMAP.md](https://github.com/AristoRap/lune/blob/main/ROADMAP.md)). The runtime still exports a `FileDrop` namespace on Windows so cross-platform imports keep working, but `lune.FileDrop.on(cb)` is a one-time `console.warn` + no-op — the callback never fires. Guard with `lune.System.environment().os` or simply accept that drops won't trigger on Win32.

---

## Disabling

```yaml
plugins:
  disabled:
    - file_drop
```

On Windows you don't need to disable it manually — the platform filter handles it. The `disabled:` entry is only useful on macOS / Linux.

---

## Platform notes

- **macOS** — Verified.
- **Linux** — Untested.
- **Windows** — Not implemented. Needs `IDropTarget` + `OleInitialize`. Auto-filtered by plugin registry on Windows.
