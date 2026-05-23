# DragOut

> Initiate a native drag-out operation from the app to the desktop or Finder.

|                  |                                |
| ---------------- | ------------------------------ |
| **Config key**   | `drag_out`                     |
| **JS namespace** | `DragOut`                      |
| **Core**         | No                             |
| **Phases**       | Bindable                       |
| **Hard deps**    | —                              |
| **Platforms**    | macOS (Linux/Windows: planned) |

DragOut lets users drag files from your app's UI to external targets — Finder, the Desktop, other apps. Call `lune.DragOut.start` from a `mousedown` or `dragstart` handler with the file paths to drag.

---

## JavaScript API

```js
import { lune } from "../lunejs/runtime/runtime.js";

fileCard.addEventListener("mousedown", async (e) => {
  await lune.DragOut.start(["/path/to/file.png"]);
});
```

Multiple paths can be dragged at once:

```js
await lune.DragOut.start(["/exports/chart.png", "/exports/data.csv"]);
```

| Method  | Signature                | Returns         |
| ------- | ------------------------ | --------------- |
| `start` | `start(paths: string[])` | `Promise<void>` |

---

## Notes

- Paths must be absolute.
- The drag operation is native and modal — `start` resolves once the drag ends (drop or cancel).
- **macOS only.** On Linux/Windows the runtime still exports a `DragOut` namespace, but `start(...)` returns a rejected `Promise` carrying a `LuneError` with code `"UNAVAILABLE_ON_PLATFORM"`. Catch it (or branch on `lune.System.environment().os` ahead of time) to fall back gracefully:

```js
try {
  await lune.DragOut.start(["/exports/chart.png"]);
} catch (err) {
  if (err.code === "UNAVAILABLE_ON_PLATFORM") {
    // Show a fallback "Download" button, etc.
  } else {
    throw err;
  }
}
```

---

## Platform notes

- **macOS** — Verified.
- **Linux** — Not implemented. Tracked in [ROADMAP.md](https://github.com/AristoRap/lune/blob/main/ROADMAP.md).
- **Windows** — Not implemented. Needs OLE `DoDragDrop` + `IDataObject` / `IDropSource`.

---

## Disabling

```yaml
plugins:
  disabled:
    - drag_out
```
