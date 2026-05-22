# Window

> Programmatic window controls from JavaScript.

|                  |                                                  |
| ---------------- | ------------------------------------------------ |
| **Config key**   | `window`                                         |
| **JS namespace** | `Window`                                         |
| **Core**         | No                                               |
| **Phases**       | Bindable                                         |
| **Hard deps**    | —                                                |
| **Platforms**    | macOS · Linux · Windows (chrome opts macOS-only) |

The Window plugin exposes runtime window controls to JavaScript — minimize, maximize, center, resize, and retitle. For initial window size, title, and macOS-specific options, see [Window Configuration](../guide/window).

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

---

## Notes

- `setSize` sets the content area in logical pixels (independent of screen DPI).
- For initial size and position constraints (`min_width`, `max_width`, etc.) use the [Window Configuration](../guide/window) options.

---

## Platform notes

- **macOS** — Verified.
- **Linux** — Untested.
- **Windows** — Verified. Window state opt-in via `remember_frame = true` (live `GetWindowRect` tracker since HWND is destroyed before save). `chrome` opts are macOS-only.

---

## Disabling

```yaml
plugins:
  disabled:
    - window
```
