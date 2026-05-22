# FileWatch

> Monitor files and directories for filesystem changes.

|                  |                                  |
| ---------------- | -------------------------------- |
| **Config key**   | `file_watch`                     |
| **JS namespace** | `FileWatch`                      |
| **Core**         | No                               |
| **Phases**       | Bindable · Lifecycle             |
| **Hard deps**    | `events`                         |
| **Platforms**    | macOS (kqueue) · Linux (inotify) |

Backed by **kqueue** (`EVFILT_VNODE`) on macOS and **inotify** on Linux — no polling, no extra dependencies. The watcher runs on a dedicated OS thread and never stalls the UI. All watches are released automatically on window close.

Disabling `events` automatically disables this capability.

---

## Enabling

```yaml
capabilities:
  enabled:
    - file_watch
    - events # required
```

Or omit `capabilities:` entirely.

---

## JavaScript API

```js
import { FileWatch } from "../lunejs/runtime/runtime.js";

FileWatch.watch("/tmp/config.json");

FileWatch.on((event) => {
  console.log(event.path, event.kind);
  // e.g. "/tmp/config.json", "modified"
});

FileWatch.unwatch("/tmp/config.json");
```

| Method    | Signature       | Description                               |
| --------- | --------------- | ----------------------------------------- |
| `watch`   | `watch(path)`   | Start watching a file or directory        |
| `unwatch` | `unwatch(path)` | Stop watching a path                      |
| `on`      | `on(cb)`        | Persistent listener                       |
| `once`    | `once(cb)`      | One-shot listener                         |
| `off`     | `off(cb?)`      | Remove a listener, or all if `cb` omitted |

---

## Event payload

| Field  | Type                                                | Description                           |
| ------ | --------------------------------------------------- | ------------------------------------- |
| `path` | `string`                                            | The absolute path passed to `watch()` |
| `kind` | `"modified" \| "created" \| "deleted" \| "renamed"` | Type of change                        |

On macOS, `kind` maps from kqueue vnode flags (`NOTE_WRITE`/`NOTE_ATTRIB` → `"modified"`, `NOTE_DELETE` → `"deleted"`, `NOTE_RENAME` → `"renamed"`).

---

## Debounce

Editors generate several raw OS events per save. Lune debounces per path so only one event is emitted per save. The default is **50 ms**.

```crystal
Lune.run(app) do |opts|
  opts.file_watch do |fw|
    fw.debounce = 100.milliseconds  # slower editors / network filesystems
    fw.debounce = 0.milliseconds    # no debouncing — raw OS events
  end
end
```

| Option     | Type         | Default | Description                               |
| ---------- | ------------ | ------- | ----------------------------------------- |
| `debounce` | `Time::Span` | `50ms`  | Min time between events for the same path |

---

## Notes

- **No recursive watching** — each path must be registered individually. To watch a tree, enumerate and call `watch` for each path.
- Passing a directory path watches the directory for structural changes (creates, deletes, renames within it). Individual file events inside the directory are not reported — watch the files directly if you need per-file granularity.

---

## Windows behaviour

The capability is auto-filtered from the registry on Windows (Win32 needs `ReadDirectoryChangesW` plumbing — tracked in [ROADMAP.md](https://github.com/AristoRap/lune/blob/main/ROADMAP.md)). The runtime still exports a `FileWatch` namespace on Windows so cross-platform imports keep working, but the methods don't do real work: `watch(path)` / `unwatch(path)` reject with `LuneError("UNAVAILABLE_ON_PLATFORM", …)`, and `on` / `once` / `off` are a one-time `console.warn` + no-op. Catch the rejection or guard with `runtime.System.environment().os`.

---

## Disabling

```yaml
capabilities:
  disabled:
    - file_watch
```

On Windows you don't need to disable it manually — the platform filter handles it. The `disabled:` entry is only useful on macOS / Linux.

---

## Platform notes

- **macOS** — Verified. Backed by kqueue `EVFILT_VNODE`.
- **Linux** — Untested. Backed by inotify.
- **Windows** — Not implemented. Needs `ReadDirectoryChangesW`. Auto-filtered by capability registry on Windows.
