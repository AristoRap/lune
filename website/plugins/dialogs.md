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
plugins:
  disabled:
    - dialogs
```
