# FileWatch

> Monitor files and directories for filesystem changes.

|                  |                                  |
| ---------------- | -------------------------------- |
| **Config key**   | `file_watch`                     |
| **JS namespace** | `FileWatch`                      |
| **Core**         | No                               |
| **Phases**       | Bindable · Lifecycle             |
| **Hard deps**    | `event_bus`                      |
| **Platforms**    | macOS (kqueue) · Linux (inotify) |

Backed by **kqueue** (`EVFILT_VNODE`) on macOS and **inotify** on Linux — no polling, no extra dependencies. The watcher runs on a dedicated OS thread and never stalls the UI. All watches are released automatically on window close.

Disabling `event_bus` automatically disables this capability.

---

## Enabling

```yaml
capabilities:
  include:
    - file_watch
    - event_bus # required
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

## Disabling

```yaml
capabilities:
  exclude:
    - file_watch
```
