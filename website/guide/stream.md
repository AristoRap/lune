# Stream

Lune includes a WebSocket-backed IPC stream for ordered, low-latency data delivery between Crystal and JavaScript. Use it when you need high-frequency or continuous streams — price ticks, log lines, LLM token output, sensor data — where firing a new `evaluateJavaScript` call per message would saturate the event loop.

For the full API reference see [Stream capability](../capabilities/stream).

---

## Crystal → JavaScript

Call `app.stream_send` from any fiber:

```crystal
app.stream_send("tick", { "price" => 45123.50 })
app.stream_send("log-line", "build finished in 4.2s")
```

Listen in JavaScript with `Stream.on`:

```js
import { Stream } from "../lunejs/runtime/runtime.js";

Stream.on("tick", ({ price }) => renderTicker(price));
Stream.once("ready", () => showReadyState());
```

---

## JavaScript → Crystal

Fire-and-forget with `Stream.send` — no `await` needed:

```js
Stream.send("stream-start");
Stream.send("order", { symbol: "BTC", qty: 1 });
```

Listen in Crystal with `app.stream_on`:

```crystal
app.stream_on("order") do |data|
  place_order(data["symbol"].as_s, data["qty"].as_i)
end
```

---

## Events vs Stream

Use Events for discrete, low-frequency signals; use Stream for sustained data flows.

|              | Events                            | Stream                            |
| ------------ | --------------------------------- | --------------------------------- |
| Transport    | `evaluateJavaScript` per call     | WebSocket frames                  |
| JS → Crystal | `await Events.emit(...)`          | `Stream.send(...)` (no await)     |
| Throughput   | Low–medium                        | High (batched WS frames)          |
| Ordering     | Best-effort                       | Guaranteed per-connection         |
| Best for     | UI signals, one-off notifications | Tickers, log tails, token streams |

---

See [Stream capability](../capabilities/stream) for the full API reference including common patterns and listener management.
