# Event

Lune has a unified, bidirectional event bus. Crystal can push events to the frontend, and the frontend can push events back to Crystal — using the same event names on both sides.

For the full API reference see [Event plugin](../plugins/event).

---

## Crystal → JavaScript

Call `app.event.emit` with an event name and an optional payload:

```crystal
app.event.emit("status-changed", "ready")
app.event.emit("progress", { "percent" => 42 })
app.event.emit("file-saved")
```

Listen in JavaScript with `lune.Event.on` or `lune.Event.once`:

```js
import { lune } from "../lunejs/runtime/runtime.js";

lune.Event.on("status-changed", (status) => console.log(status));
lune.Event.once("connected", () => showWelcomeMessage());
```

---

## JavaScript → Crystal

Emit from JavaScript with `lune.Event.emit`:

```js
await lune.Event.emit("search", { query: input.value });
```

Listen in Crystal with `app.event.on` or `app.event.once`:

```crystal
app.event.on("search") do |data|
  results = search_index(data["query"].as_s)
  app.event.emit("results", results)
end
```

---

## Unified bus

Crystal-emitted events are received by JS listeners and vice versa — names live in one shared namespace:

```crystal
# Crystal side
app.event.on("search") do |data|
  app.event.emit("results", run_search(data["query"].as_s))
end
```

```js
// JS side
lune.Event.on("results", (data) => renderList(data));
searchButton.addEventListener("click", () =>
  lune.Event.emit("search", { query: input.value }),
);
```

---

## Timing

`app.event.emit` is safe to call from any fiber. Events emitted before the WebView is open are silently dropped — emit from `on_load` or in response to a JS event to guarantee delivery.

Crystal `app.event.on` handlers run on the webview main thread. Keep them short; dispatch long work to `app.async`.

---

## Event vs Stream

For high-frequency or ordered data flows, use [Stream](./stream) instead of `lune.Event`.

|           | Event                             | Stream                            |
| --------- | --------------------------------- | --------------------------------- |
| Transport | `evaluateJavaScript` per call     | WebSocket frames                  |
| Best for  | UI signals, one-off notifications | Tickers, log lines, token streams |

---

See [Event plugin](../plugins/event) for the full API reference including common patterns, TypeScript types, and listener management.
