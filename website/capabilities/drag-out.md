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

DragOut lets users drag files from your app's UI to external targets — Finder, the Desktop, other apps. Call `DragOut.start` from a `mousedown` or `dragstart` handler with the file paths to drag.

---

## JavaScript API

```js
import { DragOut } from "../lunejs/runtime/runtime.js";

fileCard.addEventListener("mousedown", async (e) => {
  await DragOut.start(["/path/to/file.png"]);
});
```

Multiple paths can be dragged at once:

```js
await DragOut.start(["/exports/chart.png", "/exports/data.csv"]);
```

| Method  | Signature                | Returns         |
| ------- | ------------------------ | --------------- |
| `start` | `start(paths: string[])` | `Promise<void>` |

---

## Notes

- Paths must be absolute.
- The drag operation is native and modal — `start` resolves once the drag ends (drop or cancel).
- Only available on macOS in the current release.

---

## Disabling

```yaml
capabilities:
  exclude:
    - drag_out
```
