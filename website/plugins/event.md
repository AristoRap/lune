# Event

> Bidirectional event bus between Crystal and JavaScript.

|                  |                                                                                        |
| ---------------- | -------------------------------------------------------------------------------------- |
| **Config key**   | `event`                                                                                |
| **JS namespace** | `Event`                                                                                |
| **Core**         | **Yes** — disabling cascades to `context_menu`, `deep_link`, `file_drop`, `file_watch` |
| **Phases**       | WebviewInject                                                                          |
| **Hard deps**    | —                                                                                      |
| **Platforms**    | macOS · Linux · Windows                                                                |

Event is the primary channel for discrete signals between your Crystal backend and the JS frontend. For sustained high-frequency data flows see [Stream](./stream).

---

## Disabling

Event is active by default. You can disable it, but any plugin that hard-depends on it (`context_menu`, `deep_link`, `file_drop`, `file_watch`) will be automatically disabled with a warning.

```yaml
plugins:
  disabled:
    - event
```

---

## Crystal → JavaScript

### Emitting from Crystal

```crystal
app.event.emit("status-changed", "ready")
app.event.emit("progress", { "percent" => 42 })
app.event.emit("file-saved")  # no payload
```

The payload can be any Crystal value that serializes to JSON — strings, numbers, booleans, arrays, hashes, or `JSON::Serializable` structs.

### Listening in JavaScript

```js
import { lune } from "../lunejs/runtime/runtime.js";

lune.Event.on("status-changed", (status) => {
  console.log("New status:", status);
});

// One-shot listener — fires once, then removes itself
lune.Event.once("connected", () => showWelcomeMessage());
```

---

## JavaScript → Crystal

### Emitting from JavaScript

```js
await lune.Event.emit("search", { query: input.value });
await lune.Event.emit("user-action", "button-clicked");
await lune.Event.emit("ready");
```

`lune.Event.emit` is async — it resolves once Crystal has received the event.

### Listening in Crystal

```crystal
app.event.on("search") do |data|
  query = data["query"].as_s
  results = search_index(query)
  app.event.emit("results", results)
end

app.event.once("ready") do |_|
  puts "Frontend is ready"
end

app.event.off("search")  # remove all Crystal-side handlers
```

The `data` argument is a `JSON::Any` — use `.as_s`, `.as_i`, `.as_a`, `[]` etc.

---

## JavaScript API

| Method | Signature           | Description                                        |
| ------ | ------------------- | -------------------------------------------------- |
| `on`   | `on(name, cb)`      | Persistent listener                                |
| `once` | `once(name, cb)`    | One-shot listener                                  |
| `off`  | `off(name, cb?)`    | Remove a specific listener, or all if `cb` omitted |
| `emit` | `emit(name, data?)` | Send an event to Crystal; returns `Promise<void>`  |

---

## Removing listeners

```js
const handler = (data) => console.log(data);

lune.Event.on("tick", handler);
lune.Event.off("tick", handler); // remove this handler
lune.Event.off("tick"); // remove ALL handlers for "tick"
```

---

## Common patterns

### Progress reporting

```crystal
@[Lune::Bind(async: true)]
def process_files(paths : Array(String)) : Nil
  paths.each_with_index do |path, i|
    do_work(path)
    @app.event.emit("progress", { "done" => i + 1, "total" => paths.size })
  end
end
```

```js
lune.Event.on("progress", ({ done, total }) => {
  progressBar.value = done / total;
});
```

### Request/reply pattern

```crystal
app.event.on("search") do |data|
  results = run_search(data["query"].as_s)
  app.event.emit("search-results", results.map(&.to_h))
end
```

```js
lune.Event.on("search-results", (results) => renderResults(results));
searchInput.addEventListener("input", (e) => {
  lune.Event.emit("search", { query: e.target.value });
});
```

### Signal from JS when frontend is ready

```crystal
app.event.once("frontend-ready") do |_|
  app.event.emit("config", load_config.to_h)
end
```

```js
lune.Event.on("config", (cfg) => applyConfig(cfg));
lune.Event.emit("frontend-ready");
```

---

## Notes

- `app.event.emit` is safe to call from any fiber — `app.async` tasks, async binding callbacks, or the main thread.
- Events emitted before the WebView has finished loading (e.g. a cold-start `deep_link` that launched the app, or anything emitted from a plugin's `install`) are held in a small in-memory queue and flushed in order the moment the JS bridge is alive. The queue holds up to 64 entries; on overflow the oldest is dropped and a warning is logged. JS-side listeners registered at module scope (or inside `onMounted` on a globally-mounted component) receive cold-start events on first render.
- Crystal `app.event.on` handlers run on the webview main thread. Keep them short; dispatch long work to `app.async`.
- For high-frequency or ordered streams, use [Stream](./stream) instead.

---

## Platform notes

- **macOS** — Verified.
- **Linux** — Untested.
- **Windows** — Verified.
