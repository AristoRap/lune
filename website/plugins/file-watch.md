# FileWatch

> Monitor files and directories for filesystem changes.

|                  |                         |
| ---------------- | ----------------------- |
| **Config key**   | `file_watch`            |
| **JS namespace** | `FileWatch`             |
| **Core**         | No                      |
| **Phases**       | Bindable · Lifecycle    |
| **Hard deps**    | `event`                 |
| **Platforms**    | macOS · Linux · Windows |

Backed by **kqueue** (`EVFILT_VNODE`) on macOS, **inotify** on Linux, and **ReadDirectoryChangesW + IOCP** on Windows — no polling, no extra dependencies. The watcher runs on a dedicated OS thread and never stalls the UI. All watches are released automatically on window close.

Disabling `event` automatically disables this plugin.

---

## Enabling

```yaml
plugins:
  enabled:
    - file_watch
    - event # required
```

Or omit `plugins:` entirely.

---

## JavaScript API

```js
import { lune } from "../lunejs/runtime/runtime.js";

lune.FileWatch.watch("/tmp/config.json");

lune.FileWatch.on((event) => {
  console.log(event.path, event.kind);
  // e.g. "/tmp/config.json", "modified"
});

lune.FileWatch.unwatch("/tmp/config.json");
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

On macOS, `kind` maps from kqueue vnode flags (`NOTE_WRITE`/`NOTE_ATTRIB` → `"modified"`, `NOTE_DELETE` → `"deleted"`, `NOTE_RENAME` → `"renamed"`). On Windows, `FILE_ACTION_ADDED` → `"created"`, `FILE_ACTION_REMOVED` → `"deleted"`, `FILE_ACTION_MODIFIED` → `"modified"`, both rename actions → `"renamed"`.

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
plugins:
  disabled:
    - file_watch
```

---

## Platform notes

- **macOS** — Verified. Backed by kqueue `EVFILT_VNODE`.
- **Linux** — Untested. Backed by inotify.
- **Windows** — Verified. Backed by `ReadDirectoryChangesW` + IOCP, one HANDLE per watched path (parent dir when the path is a file, the dir itself otherwise). Buffer-overflow events (kernel returns 0 bytes) are dropped silently, matching macOS/Linux's best-effort posture.
