# Stream

> WebSocket-backed IPC stream for high-frequency or ordered data delivery.

|                  |                                         |
| ---------------- | --------------------------------------- |
| **Config key**   | `stream`                                |
| **JS namespace** | `Stream`                                |
| **Core**         | **Yes** — disabling cascades to `shell` |
| **Phases**       | WebviewInject                           |
| **Hard deps**    | —                                       |
| **Platforms**    | macOS · Linux · Windows                 |

Stream uses a local WebSocket server for ordered, low-latency data delivery. Use it for sustained flows — price ticks, log lines, LLM tokens, sensor data — where firing a new `evaluateJavaScript` call per message would saturate the event loop. For discrete, low-frequency signals see [EventBus](./event-bus).

---

## Disabling

Stream is active by default. Disabling it automatically disables `shell`.

```yaml
capabilities:
  exclude:
    - stream
```

---

## Crystal → JavaScript

### Sending from Crystal

```crystal
app.stream.send("trade", { "symbol" => "BTC", "price" => 45123.50 })
app.stream.send("log-line", "build finished in 4.2s")
app.stream.send("heartbeat")  # no payload
```

`app.stream.send` is safe to call from any fiber. If no WebSocket client is connected, the call is a silent no-op.

### Listening in JavaScript

```js
import { Stream } from "../lunejs/runtime/runtime.js";

Stream.on("trade", (tick) => {
  console.log(tick.symbol, tick.price);
});

Stream.once("ready", () => showReadyState());
```

---

## JavaScript → Crystal

### Sending from JavaScript

```js
Stream.send("stream-start");
Stream.send("order", { symbol: "BTC", qty: 1, side: "buy" });
```

`Stream.send` is fire-and-forget — no `await` needed.

### Listening in Crystal

```crystal
app.stream.on("order") do |data|
  place_order(data["symbol"].as_s, data["qty"].as_i)
end

app.stream.off("order")  # remove all handlers for this name
```

Handlers run in the stream's background fiber pool — keep them short or hand off to `app.async`.

---

## JavaScript API

| Method | Signature           | Description                                        |
| ------ | ------------------- | -------------------------------------------------- |
| `on`   | `on(name, cb)`      | Subscribe to a named channel                       |
| `once` | `once(name, cb)`    | One-shot subscription                              |
| `off`  | `off(name, cb?)`    | Remove a specific listener, or all if `cb` omitted |
| `send` | `send(name, data?)` | Fire-and-forget message to Crystal                 |

---

## Common patterns

### High-frequency ticker

```crystal
streaming = Atomic(Int32).new(0)

app.stream.on("stream-start") { |_| streaming.set(1) }
app.stream.on("stream-stop")  { |_| streaming.set(0) }

app.async("ticker") do
  loop do
    if streaming.get == 1
      app.stream.send("tick", { "price" => current_price })
      sleep 50.milliseconds
    else
      sleep 100.milliseconds
    end
  end
end
```

```js
Stream.on("tick", ({ price }) => renderTicker(price));
startButton.addEventListener("click", () => Stream.send("stream-start"));
stopButton.addEventListener("click", () => Stream.send("stream-stop"));
```

### LLM token streaming

```crystal
app.async do
  client.stream_chat(prompt) do |token|
    app.stream.send("token", token)
  end
  app.stream.send("done", nil)
end
```

```js
let output = "";
Stream.on("token", (tok) => {
  output += tok;
  el.textContent = output;
});
Stream.once("done", () => {
  el.dataset.streaming = "false";
});
```

### Log tail

```crystal
app.async do
  File.open("/var/log/app.log") do |f|
    f.seek(0, IO::Seek::End)
    loop do
      line = f.gets
      line ? app.stream.send("log", line) : sleep(200.milliseconds)
    end
  end
end
```

---

## Events vs Stream

|              | Events                            | Stream                            |
| ------------ | --------------------------------- | --------------------------------- |
| Transport    | `evaluateJavaScript` per call     | WebSocket frames                  |
| JS → Crystal | `await Events.emit(...)`          | `Stream.send(...)` (no await)     |
| Throughput   | Low–medium                        | High (batched WS frames)          |
| Ordering     | Best-effort                       | Guaranteed per-connection         |
| Best for     | UI signals, one-off notifications | Tickers, log tails, token streams |
