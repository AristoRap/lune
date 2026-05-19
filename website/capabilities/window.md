# Window

> Programmatic window controls from JavaScript.

|                  |                                  |
| ---------------- | -------------------------------- |
| **Config key**   | `window`                         |
| **JS namespace** | `Window`                         |
| **Core**         | No                               |
| **Phases**       | Bindable                         |
| **Hard deps**    | —                                |
| **Platforms**    | macOS · Linux (Windows: planned) |

The Window capability exposes runtime window controls to JavaScript — minimize, maximize, center, resize, and retitle. For initial window size, title, and macOS-specific options, see [Window Configuration](../guide/window).

---

## JavaScript API

```js
import { Window } from "../lunejs/runtime/runtime.js";

await Window.minimize();
await Window.maximize();
await Window.center();

await Window.setTitle("My App — Unsaved");
await Window.setSize(1440, 900);
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

## Disabling

```yaml
capabilities:
  exclude:
    - window
```
