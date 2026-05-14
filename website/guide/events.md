# Events

Bindings let the frontend call Crystal. Events go the other direction — Crystal pushes data to the frontend at any time, without the frontend having to poll.

---

## Emitting from Crystal

Call `app.emit` with an event name and an optional payload:

```crystal
app.emit("status-changed", "ready")
app.emit("progress", { "percent" => 42 })
app.emit("file-saved")  # no payload
```

The payload can be any Crystal value that serializes to JSON — strings, numbers, booleans, arrays, hashes, or `JSON::Serializable` structs.

---

## Listening in JavaScript

Import `on`, `once`, or `off` from `runtime.js`:

```js
import { on, once, off } from '../lunejs/runtime/runtime.js'

// Persistent listener
on('status-changed', (status) => {
  console.log('New status:', status)
})

// One-shot listener — fires once, then removes itself
once('connected', () => {
  showWelcomeMessage()
})
```

---

## Removing listeners

```js
const handler = (data) => console.log(data)

on('tick', handler)

// Later, remove this specific handler
off('tick', handler)

// Remove ALL handlers for this event
off('tick')
```

---

## Common patterns

### Progress reporting

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
on('progress', ({ done, total, path }) => {
  progressBar.value = done / total
  statusLabel.textContent = `Processing ${path}...`
})

await api.Files.ProcessFiles(selectedPaths)
```

### Real-time updates

Emit from background fibers or timers, completely independent of binding calls:

```crystal
spawn do
  loop do
    app.emit("cpu-usage", system_cpu_percent)
    sleep 1.second
  end
end
```

### App-level notifications

```crystal
app.emit("notification", {
  "title"   => "Download complete",
  "message" => "file.zip saved to Downloads",
})
```

---

## Timing

`app.emit` is safe to call at any point — before `Lune.run`, from background fibers, or inside binding callbacks. However, events emitted before the WebView window has opened (i.e. before the bridge is initialized) are silently dropped. In practice, emit from `on_load` or after the window is visible to guarantee delivery.

---

## TypeScript

The runtime type declarations are in `runtime.d.ts`. The event callback receives `unknown` by default — cast to your expected type:

```ts
import { on } from '../lunejs/runtime/runtime.js'

interface Progress {
  done: number
  total: number
  path: string
}

on('progress', (data) => {
  const p = data as Progress
  console.log(`${p.done}/${p.total}`)
})
```
