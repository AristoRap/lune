# EditShortcuts

> Wire cmd/ctrl + A/C/V/X/Z/Y to native edit commands inside the webview.

|                  |                         |
| ---------------- | ----------------------- |
| **Config key**   | `edit_shortcuts`        |
| **JS namespace** | — (no namespace)        |
| **Core**         | No                      |
| **Phases**       | WebviewInject           |
| **Hard deps**    | —                       |
| **Platforms**    | macOS · Linux · Windows |

A passive plugin — injects a single `keydown` listener that maps the standard edit-action shortcuts (Select All, Copy, Paste, Cut, Undo, Redo) to `document.execCommand`. Nothing to configure; opt out via `lune.yml` if your app handles these keys itself.

---

## What it does

Adds a top-level `keydown` listener:

| Shortcut               | Action      |
| ---------------------- | ----------- |
| `cmd/ctrl + A`         | `selectAll` |
| `cmd/ctrl + C`         | `copy`      |
| `cmd/ctrl + V`         | `paste`     |
| `cmd/ctrl + X`         | `cut`       |
| `cmd/ctrl + Z`         | `undo`      |
| `cmd/ctrl + shift + Z` | `redo`      |
| `cmd/ctrl + Y`         | `redo`      |

The listener calls `e.preventDefault()` then `document.execCommand(...)`. Any other key combination falls through to the page.

---

## Disabling

```yaml
plugins:
  disabled:
    - edit_shortcuts
```

Disable when your app already binds these shortcuts (e.g. a custom code editor view that needs raw `cmd+Z` semantics).

---

## Platform notes

- **macOS** — Verified.
- **Linux** — Untested.
- **Windows** — Verified.
