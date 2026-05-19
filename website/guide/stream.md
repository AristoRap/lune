# Stream

Lune includes a WebSocket-backed IPC stream for ordered, low-latency data delivery between Crystal and JavaScript. Use it when you need high-frequency or continuous streams — price ticks, log lines, LLM token output, sensor data — where firing a new `evaluateJavaScript` call per message would saturate the event loop.

The event bus and the stream are complementary: use `Events` for discrete, low-frequency signals; use `Stream` for sustained data flows.

---

## Crystal → JavaScript

### Sending from Crystal

Call `app.stream_send` with a name and an optional payload:

```crystal
app.stream_send("trade", { "symbol" => "BTC", "price" => 45123.50 })
app.stream_send("log-line", "build finished in 4.2s")
app.stream_send("heartbeat")  # no payload
```

The payload can be any Crystal value that serializes to JSON.

`stream_send` is safe to call from any fiber — `app.async` background tasks, async binding callbacks, or the main thread. If no WebSocket client is connected, the call is a silent no-op.

### Listening in JavaScript

Import the `Stream` namespace from `runtime.js`:

```js
import { Stream } from "../lunejs/runtime/runtime.js";

Stream.on("trade", (tick) => {
  console.log(tick.symbol, tick.price);
});

Stream.once("connected", () => {
  showReadyState();
});
```

---

## JavaScript → Crystal

### Sending from JavaScript

Use `Stream.send` — it is fire-and-forget, no `await` needed:

```js
Stream.send("stream-start");
Stream.send("order", { symbol: "BTC", qty: 1, side: "buy" });
```

### Listening in Crystal

Register handlers with `app.stream_on`:

```crystal
app.stream_on("order") do |data|
  symbol = data["symbol"].as_s
  qty    = data["qty"].as_i
  place_order(symbol, qty)
end

app.stream_off("order")  # remove all handlers for this name
```

The `data` argument is a `JSON::Any`. Handlers run in the stream's background fiber pool — keep them short or hand off to `app.async`.

---

## Common patterns

### Simulated high-frequency stream

```crystal
streaming = Atomic(Int32).new(0)

app.stream_on("stream-start") { |_| streaming.set(1) }
app.stream_on("stream-stop")  { |_| streaming.set(0) }

app.async("ticker") do
  prices = { "BTC" => 45000.0_f64 }
  loop do
    if streaming.get == 1
      delta = (Random.rand - 0.5) * prices["BTC"] * 0.002
      prices["BTC"] = (prices["BTC"] + delta).round(2)
      app.stream_send("tick", { "symbol" => "BTC", "price" => prices["BTC"] })
      sleep 50.milliseconds
    else
      sleep 100.milliseconds
    end
  end
end
```

```js
const prices = {};

Stream.on("tick", ({ symbol, price }) => {
  prices[symbol] = price;
  renderTicker(prices);
});

startButton.addEventListener("click", () => Stream.send("stream-start"));
stopButton.addEventListener("click",  () => Stream.send("stream-stop"));
```

### LLM token streaming

Crystal calls the API and streams tokens as they arrive:

```crystal
app.async do
  client.stream_chat(prompt) do |token|
    app.stream_send("token", token)
  end
  app.stream_send("done", nil)
end
```

```js
let output = "";

Stream.on("token", (tok) => {
  output += tok;
  responseEl.textContent = output;
});

Stream.once("done", () => {
  responseEl.dataset.streaming = "false";
});
```

### Tailing a log file

```crystal
app.async do
  File.open("/var/log/app.log") do |f|
    f.seek(0, IO::Seek::End)
    loop do
      line = f.gets
      if line
        app.stream_send("log", line)
      else
        sleep 200.milliseconds
      end
    end
  end
end
```

```js
const logEl = document.getElementById("log");
Stream.on("log", (line) => {
  logEl.textContent += line + "\n";
  logEl.scrollTop = logEl.scrollHeight;
});
```

---

## Removing listeners

**JavaScript:**

```js
const handler = (data) => console.log(data);

Stream.on("tick", handler);
Stream.off("tick", handler);   // remove this specific handler
Stream.off("tick");            // remove all handlers for "tick"
```

**Crystal:**

```crystal
app.stream_off("order")  # removes all Crystal-side handlers for "order"
```

---

## Disabling the stream

The Stream capability is active by default. You can exclude it in `lune.yml` if your app doesn't use it:

```yaml
capabilities:
  exclude:
    - stream
```

---

## Compared to Events

| | Events | Stream |
|---|---|---|
| Transport | `evaluateJavaScript` per call | WebSocket frames |
| JS → Crystal | `await Events.emit(...)` | `Stream.send(...)` (no await) |
| Throughput | Low–medium (one JS eval per event) | High (batched WS frames) |
| Ordering | Best-effort | Guaranteed per-connection |
| Best for | UI signals, one-off notifications | Streams, tickers, log tails |
