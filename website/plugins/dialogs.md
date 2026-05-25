# Dialogs

> Native file pickers and message dialogs.

|                  |                         |
| ---------------- | ----------------------- |
| **Config key**   | `dialogs`               |
| **JS namespace** | `Dialogs`               |
| **Core**         | No                      |
| **Phases**       | Bindable                |
| **Hard deps**    | —                       |
| **Platforms**    | macOS · Linux · Windows |

---

## JavaScript API

All methods return a `Promise` and block until the user dismisses the dialog.

### File pickers

```js
import { lune } from "../lunejs/runtime/runtime.js";

// Single file
const path = await lune.Dialogs.openFile("Select a config file");
if (path) loadConfig(path);

// Directory
const dir = await lune.Dialogs.openDir("Choose output folder");

// Multiple files
const paths = await lune.Dialogs.openFiles("Select images");

// Save dialog
const dest = await lune.Dialogs.saveFile("Save as", "output.csv");
```

File pickers return an empty string (or empty array for `openFiles`) when the user cancels.

#### File-type filters

`openFile`, `openFiles`, and `saveFile` accept an optional `filters` array that constrains the picker to specific extensions:

```js
const path = await lune.Dialogs.openFile("Choose an icon", [
  { name: "Tray icons", extensions: ["ico", "icns", "png", "svg"] },
]);

const paths = await lune.Dialogs.openFiles("Pick images", [
  { name: "Raster", extensions: ["png", "jpg", "jpeg"] },
  { name: "Vector", extensions: ["svg"] },
]);

const dest = await lune.Dialogs.saveFile("Export", "data.csv", [
  { name: "CSV", extensions: ["csv"] },
  { name: "JSON", extensions: ["json"] },
]);
```

Each filter is `{ name: string, extensions: string[] }` — pass extensions WITHOUT the leading dot (`"png"`, not `".png"`). Omitted or empty array = no filtering. Behaviour per platform:

- **Windows** maps to `lpstrFilter` on `GetOpenFileNameW` / `GetSaveFileNameW`; multiple filters show as a dropdown ("Tray icons (_.ico;_.icns;…)"). `saveFile` also sets `lpstrDefExt` to the first extension of the first filter, so a name typed without an extension auto-gains one.
- **macOS** maps to `NSOpenPanel.allowedFileTypes` / `NSSavePanel.allowedFileTypes`. AppKit's older API is a flat union — multiple groups collapse into a single allowed-extensions set (no in-dialog dropdown).
- **Linux** adds one `GtkFileFilter` per group; each extension becomes a `*.ext` glob. GTK shows a dropdown when multiple filters are present.

### Message dialogs

```js
await lune.Dialogs.messageInfo(
  "Update available",
  "Version 2.0 is ready to install.",
);
await lune.Dialogs.messageWarning(
  "Low disk space",
  "Less than 1 GB remaining.",
);
await lune.Dialogs.messageError(
  "Export failed",
  "Could not write to the destination.",
);

// Question — returns the label of the clicked button
const answer = await lune.Dialogs.messageQuestion(
  "Confirm",
  "Delete all files?",
);
if (answer === "OK") deleteAll();
```

---

## Full API reference

| Method            | Signature                              | Returns                          |
| ----------------- | -------------------------------------- | -------------------------------- |
| `openFile`        | `openFile(prompt, filters?)`           | `Promise<string>` — path or `""` |
| `openDir`         | `openDir(prompt)`                      | `Promise<string>` — path or `""` |
| `openFiles`       | `openFiles(prompt, filters?)`          | `Promise<string[]>`              |
| `saveFile`        | `saveFile(prompt, filename, filters?)` | `Promise<string>` — path or `""` |
| `messageInfo`     | `messageInfo(title, message)`          | `Promise<void>`                  |
| `messageWarning`  | `messageWarning(title, message)`       | `Promise<void>`                  |
| `messageError`    | `messageError(title, message)`         | `Promise<void>`                  |
| `messageQuestion` | `messageQuestion(title, message)`      | `Promise<string>` — button label |

`filters` is `{ name: string; extensions: string[] }[]`. Omitted or `[]` = no filter.

---

## Platform notes

- **macOS** — Verified, including file-type filters via the demo's tray icon picker. Filters map to `NSOpenPanel.allowedFileTypes` (flat union across groups; no in-dialog dropdown — see API surface above).
- **Linux** — Untested. File-type filters use one `GtkFileFilter` per group, glob patterns `*.ext`.
- **Windows** — Verified, including file-type filters via the demo's tray icon picker. Filters use `lpstrFilter` and `lpstrDefExt`; multiple filters show as a dropdown. Open / save / message icons + buttons correct since v0.11.0.

---

## Disabling

```yaml
plugins:
  disabled:
    - dialogs
```
