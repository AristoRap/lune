# Filesystem

> Resolve standard OS directories (home, downloads, app data, temp).

|                  |                         |
| ---------------- | ----------------------- |
| **Config key**   | `filesystem`            |
| **JS namespace** | `Filesystem`            |
| **Core**         | No                      |
| **Phases**       | Bindable                |
| **Hard deps**    | —                       |
| **Platforms**    | macOS · Linux · Windows |

---

## JavaScript API

```js
import { Filesystem } from "../lunejs/runtime/runtime.js";

const home = await Filesystem.homeDir();
const downloads = await Filesystem.downloadsDir();
const appData = await Filesystem.appDataDir();
const tmp = await Filesystem.tempDir();
```

| Method           | Returns           | macOS                           | Linux                                | Windows       |
| ---------------- | ----------------- | ------------------------------- | ------------------------------------ | ------------- |
| `homeDir()`      | `Promise<string>` | `~`                             | `~`                                  | `~`           |
| `downloadsDir()` | `Promise<string>` | `~/Downloads`                   | `~/Downloads`                        | `~/Downloads` |
| `appDataDir()`   | `Promise<string>` | `~/Library/Application Support` | `$XDG_DATA_HOME` or `~/.local/share` | `%APPDATA%`   |
| `tempDir()`      | `Promise<string>` | `/tmp`                          | `/tmp`                               | `%TEMP%`      |

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
    - filesystem
```
