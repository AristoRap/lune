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
import { Dialogs } from "../lunejs/runtime/runtime.js";

// Single file
const path = await Dialogs.openFile("Select a config file");
if (path) loadConfig(path);

// Directory
const dir = await Dialogs.openDir("Choose output folder");

// Multiple files
const paths = await Dialogs.openFiles("Select images");

// Save dialog
const dest = await Dialogs.saveFile("Save as", "output.csv");
```

File pickers return an empty string (or empty array for `openFiles`) when the user cancels.

### Message dialogs

```js
await Dialogs.messageInfo(
  "Update available",
  "Version 2.0 is ready to install.",
);
await Dialogs.messageWarning("Low disk space", "Less than 1 GB remaining.");
await Dialogs.messageError(
  "Export failed",
  "Could not write to the destination.",
);

// Question — returns the label of the clicked button
const answer = await Dialogs.messageQuestion("Confirm", "Delete all files?");
if (answer === "OK") deleteAll();
```

---

## Full API reference

| Method            | Signature                         | Returns                          |
| ----------------- | --------------------------------- | -------------------------------- |
| `openFile`        | `openFile(prompt)`                | `Promise<string>` — path or `""` |
| `openDir`         | `openDir(prompt)`                 | `Promise<string>` — path or `""` |
| `openFiles`       | `openFiles(prompt)`               | `Promise<string[]>`              |
| `saveFile`        | `saveFile(prompt, filename)`      | `Promise<string>` — path or `""` |
| `messageInfo`     | `messageInfo(title, message)`     | `Promise<void>`                  |
| `messageWarning`  | `messageWarning(title, message)`  | `Promise<void>`                  |
| `messageError`    | `messageError(title, message)`    | `Promise<void>`                  |
| `messageQuestion` | `messageQuestion(title, message)` | `Promise<string>` — button label |

---

## Platform notes

- **macOS** — Verified.
- **Linux** — Untested.
- **Windows** — Verified. Open/save/message all work; correct icons/buttons since v0.11.0.

---

## Disabling

```yaml
capabilities:
  disabled:
    - dialogs
```
