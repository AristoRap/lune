# Events

Lune has a unified, bidirectional event bus. Crystal can push events to the frontend, and the frontend can push events back to Crystal — using the same event names on both sides.

For the full API reference see [Events plugin](../plugins/events).

---

## Crystal → JavaScript

Call `app.events.emit` with an event name and an optional payload:

```crystal
app.events.emit("status-changed", "ready")
app.events.emit("progress", { "percent" => 42 })
app.events.emit("file-saved")
```

Listen in JavaScript with `Events.on` or `Events.once`:

```js
import { Events } from "../lunejs/runtime/runtime.js";

Events.on("status-changed", (status) => console.log(status));
Events.once("connected", () => showWelcomeMessage());
```

---

## JavaScript → Crystal

Emit from JavaScript with `Events.emit`:

```js
await Events.emit("search", { query: input.value });
```

Listen in Crystal with `app.events.on` or `app.events.once`:

```crystal
app.events.on("search") do |data|
  results = search_index(data["query"].as_s)
  app.events.emit("results", results)
end
```

---

## Unified bus

Crystal-emitted events are received by JS listeners and vice versa — names live in one shared namespace:

```crystal
# Crystal side
app.events.on("search") do |data|
  app.events.emit("results", run_search(data["query"].as_s))
end
```

```js
// JS side
Events.on("results", (data) => renderList(data));
searchButton.addEventListener("click", () =>
  Events.emit("search", { query: input.value }),
);
```

---

## Timing

`app.events.emit` is safe to call from any fiber. Events emitted before the WebView is open are silently dropped — emit from `on_load` or in response to a JS event to guarantee delivery.

Crystal `app.events.on` handlers run on the webview main thread. Keep them short; dispatch long work to `app.async`.

---

## Events vs Stream

For high-frequency or ordered data flows, use [Stream](./stream) instead of Events.

|           | Events                            | Stream                            |
| --------- | --------------------------------- | --------------------------------- |
| Transport | `evaluateJavaScript` per call     | WebSocket frames                  |
| Best for  | UI signals, one-off notifications | Tickers, log lines, token streams |

---

See [Events plugin](../plugins/events) for the full API reference including common patterns, TypeScript types, and listener management.
