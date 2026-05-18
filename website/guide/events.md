# Events

Lune has a unified, bidirectional event bus. Crystal can push events to the frontend, and the frontend can push events back to Crystal — using the same event names on both sides.

---

## Crystal → JavaScript

### Emitting from Crystal

Call `app.emit` with an event name and an optional payload:

```crystal
app.emit("status-changed", "ready")
app.emit("progress", { "percent" => 42 })
app.emit("file-saved")  # no payload
```

The payload can be any Crystal value that serializes to JSON — strings, numbers, booleans, arrays, hashes, or `JSON::Serializable` structs.

### Listening in JavaScript

Import the `Events` namespace from `runtime.js`:

```js
import { Events } from "../lunejs/runtime/runtime.js";

// Persistent listener
Events.on("status-changed", (status) => {
  console.log("New status:", status);
});

// One-shot listener — fires once, then removes itself
Events.once("connected", () => {
  showWelcomeMessage();
});
```

---

## JavaScript → Crystal

### Emitting from JavaScript

Use `Events.emit` with an event name and an optional payload:

```js
import { Events } from "../lunejs/runtime/runtime.js";

await Events.emit("search", { query: input.value });
await Events.emit("user-action", "button-clicked");
await Events.emit("ready"); // no payload
```

`Events.emit` is async — it resolves once Crystal has received the event.

### Listening in Crystal

Register handlers on the `app` object using `on`, `once`, or `off`:

```crystal
# Persistent handler
app.on("search") do |data|
  query = data["query"].as_s
  results = search_index(query)
  app.emit("results", results)
end

# One-shot handler — fires once, then removes itself
app.once("ready") do |_|
  puts "Frontend is ready"
end

# Remove all handlers for an event
app.off("search")
```

The `data` argument is a `JSON::Any` — use `.as_s`, `.as_i`, `.as_a`, `[]`, etc. to extract values.

---

## Unified event bus

Crystal-emitted events are received by JS listeners; JS-emitted events are received by Crystal listeners. The names live in one shared namespace, so you can design clean back-and-forth flows without separate channels:

```crystal
# Crystal side
app.on("search") do |data|
  results = run_search(data["query"].as_s)
  app.emit("results", results)   # reply on the same logical channel
end
```

```js
// JS side
Events.on("results", (data) => renderList(data));

searchButton.addEventListener("click", () => {
  Events.emit("search", { query: input.value });
});
```

---

## Removing listeners

**JavaScript:**

```js
const handler = (data) => console.log(data);

Events.on("tick", handler);

// Remove this specific handler
Events.off("tick", handler);

// Remove ALL handlers for this event
Events.off("tick");
```

**Crystal:**

```crystal
# off removes all Crystal-side handlers for the event
app.off("search")
```

---

## Common patterns

### Progress reporting (Crystal → JS)

Run a long task in a fiber and stream progress back:

```crystal
@[Lune::Bind(async: true)]
def process_files(paths : Array(String)) : Nil
  paths.each_with_index do |path, i|
    do_work(path)
    @app.emit("progress", {
      "done"  => i + 1,
      "total" => paths.size,
      "path"  => path,
    })
  end
end
```

```js
Events.on("progress", ({ done, total, path }) => {
  progressBar.value = done / total;
  statusLabel.textContent = `Processing ${path}...`;
});

await api.Files.processFiles(selectedPaths);
```

### Search / command dispatch (JS → Crystal → JS)

The frontend emits a request; Crystal handles it and emits back the response:

```crystal
app.on("search") do |data|
  query   = data["query"].as_s
  results = search_index(query)
  app.emit("search-results", results.map(&.to_h))
end
```

```js
Events.on("search-results", (results) => renderResults(results));

searchInput.addEventListener("input", (e) => {
  Events.emit("search", { query: e.target.value });
});
```

### Real-time updates from a background task

```crystal
app.async do
  loop do
    app.emit("cpu-usage", system_cpu_percent)
    sleep 1.second
  end
end
```

### Signalling from JS when the frontend is ready

```crystal
app.once("frontend-ready") do |_|
  # Safe to emit initial data — frontend is listening
  app.emit("config", load_config.to_h)
end
```

```js
import { Events } from "../lunejs/runtime/runtime.js";

Events.on("config", (cfg) => applyConfig(cfg));

// After your app has mounted and listeners are registered
Events.emit("frontend-ready");
```

---

## Timing

`app.emit` is safe to call from anywhere — `app.async` background tasks, async binding callbacks, or the main thread. Events emitted before the WebView has opened are silently dropped; emit from `on_load` or in response to a JS event to guarantee delivery.

Crystal `app.on` handlers run synchronously on the webview main thread. Keep them short. For anything long-running, dispatch the work to a background task:

```crystal
app.on("search") do |data|
  query = data["query"].as_s
  app.async do
    results = run_search(query)
    app.emit("results", results.map(&.to_h))
  end
end
```

---

## TypeScript

All event methods are declared in `runtime.d.ts`. Callbacks receive `unknown` by default — cast to your expected type:

```ts
import { Events } from "../lunejs/runtime/runtime.js";

interface SearchPayload {
  query: string;
}

interface SearchResult {
  title: string;
  url: string;
}

Events.on("search-results", (data) => {
  const results = data as SearchResult[];
  renderResults(results);
});

const search = (query: string) =>
  Events.emit("search", { query } satisfies SearchPayload);
```
