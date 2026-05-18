# Channel

Lune includes a WebSocket-backed IPC channel for ordered, low-latency data delivery between Crystal and JavaScript. Use it when you need high-frequency or continuous streams — price ticks, log lines, LLM token output, sensor data — where firing a new `evaluateJavaScript` call per message would saturate the event loop.

The event bus and the channel are complementary: use `Events` for discrete, low-frequency signals; use `Channel` for sustained data flows.

---

## Crystal → JavaScript

### Sending from Crystal

Call `app.channel_send` with a name and an optional payload:

```crystal
app.channel_send("trade", { "symbol" => "BTC", "price" => 45123.50 })
app.channel_send("log-line", "build finished in 4.2s")
app.channel_send("heartbeat")  # no payload
```

The payload can be any Crystal value that serializes to JSON.

`channel_send` is safe to call from any fiber — `app.async` background tasks, async binding callbacks, or the main thread. If no WebSocket client is connected, the call is a silent no-op.

### Listening in JavaScript

Import the `Channel` namespace from `runtime.js`:

```js
import { Channel } from "../lunejs/runtime/runtime.js";

Channel.on("trade", (tick) => {
  console.log(tick.symbol, tick.price);
});

Channel.once("connected", () => {
  showReadyState();
});
```

---

## JavaScript → Crystal

### Sending from JavaScript

Use `Channel.send` — it is fire-and-forget, no `await` needed:

```js
Channel.send("stream-start");
Channel.send("order", { symbol: "BTC", qty: 1, side: "buy" });
```

### Listening in Crystal

Register handlers with `app.channel_on`:

```crystal
app.channel_on("order") do |data|
  symbol = data["symbol"].as_s
  qty    = data["qty"].as_i
  place_order(symbol, qty)
end

app.channel_off("order")  # remove all handlers for this name
```

The `data` argument is a `JSON::Any`. Handlers run in the channel's background fiber pool — keep them short or hand off to `app.async`.

---

## Common patterns

### Simulated high-frequency stream

```crystal
streaming = Atomic(Int32).new(0)

app.channel_on("stream-start") { |_| streaming.set(1) }
app.channel_on("stream-stop")  { |_| streaming.set(0) }

app.async("ticker") do
  prices = { "BTC" => 45000.0_f64 }
  loop do
    if streaming.get == 1
      delta = (Random.rand - 0.5) * prices["BTC"] * 0.002
      prices["BTC"] = (prices["BTC"] + delta).round(2)
      app.channel_send("tick", { "symbol" => "BTC", "price" => prices["BTC"] })
      sleep 50.milliseconds
    else
      sleep 100.milliseconds
    end
  end
end
```

```js
const prices = {};

Channel.on("tick", ({ symbol, price }) => {
  prices[symbol] = price;
  renderTicker(prices);
});

startButton.addEventListener("click", () => Channel.send("stream-start"));
stopButton.addEventListener("click",  () => Channel.send("stream-stop"));
```

### LLM token streaming

Crystal calls the API and streams tokens as they arrive:

```crystal
app.async do
  client.stream_chat(prompt) do |token|
    app.channel_send("token", token)
  end
  app.channel_send("done", nil)
end
```

```js
let output = "";

Channel.on("token", (tok) => {
  output += tok;
  responseEl.textContent = output;
});

Channel.once("done", () => {
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
        app.channel_send("log", line)
      else
        sleep 200.milliseconds
      end
    end
  end
end
```

```js
const logEl = document.getElementById("log");
Channel.on("log", (line) => {
  logEl.textContent += line + "\n";
  logEl.scrollTop = logEl.scrollHeight;
});
```

---

## Removing listeners

**JavaScript:**

```js
const handler = (data) => console.log(data);

Channel.on("tick", handler);
Channel.off("tick", handler);   // remove this specific handler
Channel.off("tick");            // remove all handlers for "tick"
```

**Crystal:**

```crystal
app.channel_off("order")  # removes all Crystal-side handlers for "order"
```

---

## Disabling the channel

The Channel capability is active by default. You can exclude it in `lune.yml` if your app doesn't use it:

```yaml
capabilities:
  exclude:
    - channel
```

---

## Compared to Events

| | Events | Channel |
|---|---|---|
| Transport | `evaluateJavaScript` per call | WebSocket frames |
| JS → Crystal | `await Events.emit(...)` | `Channel.send(...)` (no await) |
| Throughput | Low–medium (one JS eval per event) | High (batched WS frames) |
| Ordering | Best-effort | Guaranteed per-connection |
| Best for | UI signals, one-off notifications | Streams, tickers, log tails |
