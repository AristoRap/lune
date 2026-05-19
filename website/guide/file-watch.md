# File Watch

The `file_watch` capability lets you monitor files and directories for filesystem changes. When a watched path changes, Lune emits a `"file_watch"` event on the event bus with the path and the kind of change.

Backed by **kqueue** (`EVFILT_VNODE`) on macOS and **inotify** on Linux — no polling, no extra dependencies.

---

## Enabling

File watch is off by default. Add it to your `lune.yml`:

```yaml
capabilities:
  include:
    - file_watch
    - event_bus   # required — file_watch is disabled automatically if event_bus is absent
```

Or just omit `capabilities:` entirely to enable everything.

---

## Watching from JavaScript

Call `FileWatch.watch(path)` to start watching a path, then subscribe to events with `FileWatch.on`:

```js
import { FileWatch } from "../lunejs/runtime/runtime.js";

FileWatch.watch("/tmp/config.json");

FileWatch.on((event) => {
  console.log(event.path, event.kind); // "/tmp/config.json", "modified"
});
```

Stop watching a path with `FileWatch.unwatch(path)`:

```js
FileWatch.unwatch("/tmp/config.json");
```

---

## Event payload

| Field  | Type                                              | Description                                      |
| ------ | ------------------------------------------------- | ------------------------------------------------ |
| `path` | `string`                                          | The absolute path that was passed to `watch()`   |
| `kind` | `"modified" \| "created" \| "deleted" \| "renamed"` | The type of change that occurred                 |

On macOS, `kind` maps from kqueue vnode flags (`NOTE_WRITE`/`NOTE_ATTRIB` → `"modified"`, `NOTE_DELETE` → `"deleted"`, `NOTE_RENAME` → `"renamed"`). On Linux it maps from inotify masks.

---

## JavaScript API

| Method        | Description                                                    |
| ------------- | -------------------------------------------------------------- |
| `watch(path)` | Start watching a file or directory                             |
| `unwatch(path)` | Stop watching a path                                         |
| `on(cb)`      | Subscribe to all file change events                            |
| `once(cb)`    | Subscribe and automatically unsubscribe after the first event  |
| `off(cb?)`    | Remove a specific listener, or all listeners if omitted        |

---

## Watching from Crystal

You can also start watches from Crystal using a binding callback or any background fiber:

```crystal
class WatchModule
  include Lune::Bindable

  @[Lune::Bind(async: true)]
  def start_watch(path : String) : Nil
    # nothing to do — watching is driven from JS via FileWatch.watch
    # but you can emit your own file_watch events from Crystal too:
    @app.emit("file_watch", {"path" => path, "kind" => "modified"})
  end
end
```

---

## Watching directories

Passing a directory path watches the directory itself for structural changes (files created, deleted, or renamed within it). When anything changes inside, a `"modified"` event fires for the directory path. Individual file events within the directory are not currently reported — watch the files directly if you need per-file granularity.

---

## Notes

- **No recursive watching** — each path must be registered individually. To watch a tree, enumerate the paths and call `watch` for each.
- **Non-blocking** — the watcher runs on a dedicated OS thread so it never stalls the UI.
- **Auto-cleanup** — all watches are released automatically when the window closes.
- `file_watch` hard-depends on `event_bus`. If you exclude `event_bus` from `lune.yml`, `file_watch` is automatically disabled with a warning.
