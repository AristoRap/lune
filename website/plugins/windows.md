# Windows

> Open and manage additional native windows from JavaScript.

|                  |                         |
| ---------------- | ----------------------- |
| **Config key**   | `windows`               |
| **JS namespace** | `Windows`               |
| **Core**         | No                      |
| **Phases**       | Bindable · Lifecycle    |
| **Hard deps**    | —                       |
| **Platforms**    | macOS · Linux · Windows |

The Windows plugin lets you open additional native windows from JavaScript. Each new window gets its own `WKWebView` (macOS) or equivalent, shares all active plugin bindings with the main window, and participates in `app.event.emit` broadcasts. Use it for settings panels, secondary views, or any multi-window layout.

---

## Enabling

```yaml
plugins:
  enabled:
    - windows
```

Or omit `plugins:` entirely — Windows is active by default.

---

## Opening a window

```js
import { lune } from "../lunejs/runtime/runtime.js";

const id = await lune.Windows.open({
  title: "Settings",
  url: "https://localhost:5173/settings",
  width: 640,
  height: 480,
});
```

`lune.Windows.open` returns an opaque string handle you pass to subsequent calls. The window appears immediately on the main thread; the Promise resolves once the window is created and all bindings are wired up.

### Options

| Key      | Type     | Default    | Description                             |
| -------- | -------- | ---------- | --------------------------------------- |
| `title`  | `string` | `"Window"` | Native title bar text                   |
| `url`    | `string` | —          | URL to navigate to on open              |
| `width`  | `number` | `800`      | Initial window width in logical pixels  |
| `height` | `number` | `600`      | Initial window height in logical pixels |

---

## Closing a window

```js
await lune.Windows.close(id);
```

Closes the native window and releases all resources. Both `lune.Windows.close(id)` and the user clicking the OS × button follow the same cleanup path — the bridge is torn down, the handle is freed, and the `window_closed` event fires on the main window.

---

## Listing open windows

```js
const ids = await lune.Windows.list();
// ["a3f2b1c0...", ...]
```

Returns the handles of all currently open secondary windows (the main window is not included).

---

## JavaScript API

| Method  | Signature                                       | Description                            |
| ------- | ----------------------------------------------- | -------------------------------------- |
| `open`  | `(opts: Record<string, any>) → Promise<string>` | Open a new window, return its handle   |
| `close` | `(id: string) → Promise<void>`                  | Close the window by handle             |
| `list`  | `() → Promise<string[]>`                        | List all open secondary window handles |

---

## Window closed event

When a secondary window is closed — either via `lune.Windows.close(id)` or by the user clicking the OS × button — the `window_closed` event fires in the main window:

```js
import { lune } from "../lunejs/runtime/runtime.js";

lune.Event.on("window_closed", (data) => {
  console.log("window closed:", data.id);
});
```

`data.id` is the same handle returned by `lune.Windows.open`. Use this to keep UI state in sync without polling `lune.Windows.list()`.

---

## Shared plugins

Secondary windows are fully capable — every plugin active in the main window works identically in a secondary window:

- **Bindings** (`Sqlite`, `Filesystem`, `Clipboard`, etc.) — all JS APIs work normally.
- **Event bus** — `lune.Event.on` / `lune.Event.emit` work; Crystal's `app.event.emit` broadcasts to all open windows simultaneously.
- **Stream** — the WebSocket stream connects as an additional client to the main window's existing server. No second server is started.
- **FileDrop** — drag-and-drop targets work per window.
- **Context menu, hotkeys, and all other plugins** — active in secondary windows automatically.

---

## Notes

- **No `run` needed.** Secondary windows join the existing Cocoa/GTK run loop automatically; you don't need to do anything extra to keep them alive.

---

## Platform notes

- **macOS** — Verified.
- **Linux** — Untested.
- **Windows** — Verified.

---

## Disabling

```yaml
plugins:
  disabled:
    - windows
```
