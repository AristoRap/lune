# Window

> Programmatic window controls from JavaScript and an opt-in CSS-driven window drag listener.

|                  |                                            |
| ---------------- | ------------------------------------------ |
| **Config key**   | `window`                                   |
| **JS namespace** | `Window`                                   |
| **Core**         | No                                         |
| **Phases**       | Bindable · WebviewInject                   |
| **Hard deps**    | —                                          |
| **Platforms**    | macOS · Linux · Windows (drag: macOS only) |

The Window plugin exposes runtime window controls to JavaScript — minimize, maximize, center, resize, retitle — and a CSS-driven drag listener for custom title bars. For initial window size, title, and macOS chrome options, see [Window Configuration](../guide/window).

---

## JavaScript API

```js
import { lune } from "../lunejs/runtime/runtime.js";

await lune.Window.minimize();
await lune.Window.maximize();
await lune.Window.center();

await lune.Window.setTitle("My App — Unsaved");
await lune.Window.setSize(1440, 900);
```

| Method     | Signature                | Returns         |
| ---------- | ------------------------ | --------------- |
| `minimize` | `minimize()`             | `Promise<void>` |
| `maximize` | `maximize()`             | `Promise<void>` |
| `center`   | `center()`               | `Promise<void>` |
| `setTitle` | `setTitle(title)`        | `Promise<void>` |
| `setSize`  | `setSize(width, height)` | `Promise<void>` |

`lune.Window.startDrag` is also exposed but is invoked by the auto-injected mousedown listener — application code rarely calls it directly.

---

## Window drag _(macOS only)_

Tag DOM elements with a CSS custom property and mousedown on them initiates a native window drag. Essential when using a custom title bar without the OS chrome.

```crystal
Lune.run(app) do |opts|
  opts.window.drag_zone = "--lune-draggable"
end
```

| Option      | Type     | Default | Description                                                                             |
| ----------- | -------- | ------- | --------------------------------------------------------------------------------------- |
| `drag_zone` | `String` | `""`    | CSS custom property name that marks drag handles. Empty means no listener is installed. |

Mark an element as a drag handle with an inline style. Any non-empty value on the configured property activates the drag — write `true` for clarity:

```html
<div style="--lune-draggable: true">Title bar</div>
```

> **Inline style required.** Detection reads `style.getPropertyValue` directly and walks up the DOM, so marking a container makes all children draggable too.

When `drag_zone` is empty (the default), no mousedown listener is installed and the `start_drag` binding is unused — the plugin behaves exactly like before the drag feature existed. To "disable" drag, leave `drag_zone` unset.

---

## Notes

- `setSize` sets the content area in logical pixels (independent of screen DPI).
- For initial size and position constraints (`min_width`, `max_width`, etc.) use the [Window Configuration](../guide/window) options.

---

## Platform notes

- **macOS** — Verified. Programmatic controls + drag both work.
- **Linux** — Untested. Programmatic controls only — `drag_zone` has no effect (drag needs `_NET_WM_MOVERESIZE`; tracked in [ROADMAP.md](https://github.com/AristoRap/lune/blob/main/ROADMAP.md)).
- **Windows** — Verified for programmatic controls; `drag_zone` is a no-op (needs `WM_NCLBUTTONDOWN` + `HTCAPTION`; tracked in [ROADMAP.md](https://github.com/AristoRap/lune/blob/main/ROADMAP.md)). Window state opt-in via `remember_frame = true` (live `GetWindowRect` tracker since HWND is destroyed before save). Chrome opts are macOS-only.

---

## Disabling

```yaml
plugins:
  disabled:
    - window
```

This turns off everything — the JS bindings AND the drag listener. To keep the programmatic controls but turn off drag, leave `opts.window.drag_zone` empty (the default).
