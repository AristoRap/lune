# Events

> Bidirectional event bus between Crystal and JavaScript.

|                  |                                                                                        |
| ---------------- | -------------------------------------------------------------------------------------- |
| **Config key**   | `events`                                                                               |
| **JS namespace** | `Events`                                                                               |
| **Core**         | **Yes** — disabling cascades to `context_menu`, `deep_link`, `file_drop`, `file_watch` |
| **Phases**       | WebviewInject                                                                          |
| **Hard deps**    | —                                                                                      |
| **Platforms**    | macOS · Linux · Windows                                                                |

Events is the primary channel for discrete signals between your Crystal backend and the JS frontend. For sustained high-frequency data flows see [Stream](./stream).

---

## Disabling

Events is active by default. You can disable it, but any capability that hard-depends on it (`context_menu`, `deep_link`, `file_drop`, `file_watch`) will be automatically disabled with a warning.

```yaml
capabilities:
  exclude:
    - events
```

---

## Crystal → JavaScript

### Emitting from Crystal

```crystal
app.events.emit("status-changed", "ready")
app.events.emit("progress", { "percent" => 42 })
app.events.emit("file-saved")  # no payload
```

The payload can be any Crystal value that serializes to JSON — strings, numbers, booleans, arrays, hashes, or `JSON::Serializable` structs.

### Listening in JavaScript

```js
import { Events } from "../lunejs/runtime/runtime.js";

Events.on("status-changed", (status) => {
  console.log("New status:", status);
});

// One-shot listener — fires once, then removes itself
Events.once("connected", () => showWelcomeMessage());
```

---

## JavaScript → Crystal

### Emitting from JavaScript

```js
await Events.emit("search", { query: input.value });
await Events.emit("user-action", "button-clicked");
await Events.emit("ready");
```

`Events.emit` is async — it resolves once Crystal has received the event.

### Listening in Crystal

```crystal
app.events.on("search") do |data|
  query = data["query"].as_s
  results = search_index(query)
  app.events.emit("results", results)
end

app.events.once("ready") do |_|
  puts "Frontend is ready"
end

app.events.off("search")  # remove all Crystal-side handlers
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

Events.on("tick", handler);
Events.off("tick", handler); // remove this handler
Events.off("tick"); // remove ALL handlers for "tick"
```

---

## Common patterns

### Progress reporting

```crystal
@[Lune::Bind(async: true)]
def process_files(paths : Array(String)) : Nil
  paths.each_with_index do |path, i|
    do_work(path)
    @app.events.emit("progress", { "done" => i + 1, "total" => paths.size })
  end
end
```

```js
Events.on("progress", ({ done, total }) => {
  progressBar.value = done / total;
});
```

### Request/reply pattern

```crystal
app.events.on("search") do |data|
  results = run_search(data["query"].as_s)
  app.events.emit("search-results", results.map(&.to_h))
end
```

```js
Events.on("search-results", (results) => renderResults(results));
searchInput.addEventListener("input", (e) => {
  Events.emit("search", { query: e.target.value });
});
```

### Signal from JS when frontend is ready

```crystal
app.events.once("frontend-ready") do |_|
  app.events.emit("config", load_config.to_h)
end
```

```js
Events.on("config", (cfg) => applyConfig(cfg));
Events.emit("frontend-ready");
```

---

## Notes

- `app.events.emit` is safe to call from any fiber — `app.async` tasks, async binding callbacks, or the main thread.
- Events emitted before the WebView has opened are silently dropped. Emit from `on_load` or in response to a JS event to guarantee delivery.
- Crystal `app.events.on` handlers run on the webview main thread. Keep them short; dispatch long work to `app.async`.
- For high-frequency or ordered streams, use [Stream](./stream) instead.
