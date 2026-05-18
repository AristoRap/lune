# How It Works

Lune connects a Crystal backend to a web frontend running inside a native WebView. This page explains the moving parts and how they fit together.

---

## Architecture overview

```
┌─────────────────────────────────────────────────────────┐
│                    Native Window                        │
│  ┌───────────────────────────────────────────────────┐  │
│  │                    WebView                        │  │
│  │   Your frontend (HTML / JS / CSS)                 │  │
│  │                                                   │  │
│  │   import api from '../lunejs/app/App.js'          │  │
│  │   await api.MyModule.doSomething(args)  ──────────┼──┼──┐
│  └───────────────────────────────────────────────────┘  │  │
│                    ↕ events (bidirectional)             │  │
│          app.emit() · app.on()  ↔  emit() · on()        │  │ binding call
│  ┌────────────────────────────────────────────────────┐ │  │
│  │  Crystal App                                       │ │  │
│  │                                                    │ │  │
│  │  class MyModule                                    │◄┼──┘
│  │    include Lune::Bindable                          │ │
│  │    @[Lune::Bind]                                   │ │
│  │    def do_something(args) : ReturnType             │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

---

## The binding system

Lune's bridge is built around a **compile-time annotation system**. No runtime reflection, no code generation step you have to run manually.

### 1. Annotation

You annotate Crystal methods with `@[Lune::Bind]`:

```crystal
class MyModule
  include Lune::Bindable

  @[Lune::Bind]
  def greet(name : String) : String
    "Hello, #{name}!"
  end
end
```

### 2. Macro expansion (compile time)

The `Lune::Bindable` module uses Crystal macros to inspect annotated methods at compile time. For each `@[Lune::Bind]` method it generates a call to `app.bind(...)` that registers the method name, namespace, argument types, and return type as a `Binding`.

### 3. Registration (runtime)

When you call `app.install(MyModule.new)`, the generated `install` method fires. Each binding is added to the `App`'s binding list. When the WebView starts, the `Runner` hands the full list to the `Bridge`, which wires each one as a WebView binding callback — a JavaScript-callable function backed by native code.

Lune's own built-in capabilities (lifecycle, filesystem, clipboard, window controls, dialogs, tray, notifications, screen) are registered the same way — as `Installable` classes. There is no separate path for built-in vs user bindings.

### 4. JavaScript stub generation

Lune writes four files into `frontend/lunejs/`:

- `app/App.js` — one stub function per user binding, grouped by namespace
- `app/App.d.ts` — TypeScript declarations with exact types derived from Crystal signatures
- `runtime/runtime.js` — built-in functions (`Lifecycle.quit`, `Lifecycle.openURL`, `Events.on`, `Events.emit`, …)
- `runtime/runtime.d.ts` — TypeScript declarations for runtime functions

This happens automatically on `lune dev` startup and during `lune build` (before Vite runs).

### 5. The call

When frontend code calls `api.MyModule.Greet("world")`:

1. The JS stub calls the WebView's native binding with the serialized arguments
2. The Bridge deserializes them and dispatches to the Crystal method
3. The return value is serialized as JSON and resolves the `Promise`

All binding calls return a `Promise` on the JavaScript side. Sync Crystal methods resolve immediately on the webview main thread; `async: true` methods run on a dedicated OS thread via `Fiber::ExecutionContext::Isolated`, so `sleep`, channels, and blocking IO all work without freezing the UI.

---

## JS / TS file generation

Lune runs in two modes:

| Mode  | Trigger                 | JS files                                                                                                     |
| ----- | ----------------------- | ------------------------------------------------------------------------------------------------------------ |
| Dev   | `lune dev` startup      | Written to `frontend/lunejs/` by the Crystal app after the dev server is ready, before the WebView navigates |
| Build | `lune build` → pre-pass | Crystal binary runs with `-Dbuild_mode`, writes files, exits, then Vite builds                               |

The generated files live at:

```
frontend/lunejs/
├── app/
│   ├── App.js       # binding stubs
│   └── App.d.ts     # TypeScript declarations
└── runtime/
    ├── runtime.js   # runtime, Lifecycle/Filesystem/Clipboard...
    └── runtime.d.ts # TypeScript declarations
```

---

## Threading model

Lune's native event loop (AppKit on macOS, GTK on Linux) owns the **main OS thread** for the lifetime of the app. This has consequences for how Crystal concurrency works:

| Context                         | Runs on                     | Notes                                                      |
| ------------------------------- | --------------------------- | ---------------------------------------------------------- |
| Sync binding callbacks          | Main thread                 | Keep fast — blocks the UI while running                    |
| `async: true` binding callbacks | Dedicated `Isolated` thread | Full Crystal scheduler: sleep, channels, IO                |
| `app.on` event handlers         | Main thread                 | Keep fast — dispatched synchronously on the webview thread |
| `app.async { }` tasks           | Dedicated `Isolated` thread | Use for timers, pollers, and anything long-running         |
| Asset HTTP server               | `Parallel` thread pool      | Serves embedded files in production builds                 |

**`spawn` does not work.** Crystal's default cooperative scheduler runs on the main thread, which is permanently blocked by the native event loop. Fibers spawned there are never scheduled. Use `app.async` for background work instead.

---

## Asset embedding

In production, Lune embeds your entire `frontend/dist/` directory into the Crystal binary at compile time. You opt into this by passing `assets:` to `Lune.run`:

```crystal
Lune.run(app, assets: "frontend/dist") do |opts|
  opts.title = "My App"
end
```

The `assets:` argument triggers a compile-time macro that reads every file under the path and bakes its bytes into the binary. At runtime, a small local HTTP server serves these embedded files so the WebView has a real `http://` origin — not a `file://` URI — which keeps fetch, imports, and browser security policies working correctly.

In dev mode (`lune dev`), the `LUNE_DEV_URL` environment variable overrides the embedded assets, so the WebView connects to the Vite dev server instead. No code change required between dev and production.

See [Assets & Build](./assets) for the full details.

---

## `Lune::Runner` — programmatic control

`Lune.run` is a convenience macro that covers most use cases. For finer control — loading an explicit URL, serving inline HTML, or writing tests — use `Lune::Runner` directly:

```crystal
runner = Lune::Runner.new(app) do |opts|
  opts.title = "My App"
  opts.width = 1200
end

runner.start(html: "<h1>Hello</h1>")
# or: runner.start(url: "http://localhost:3000")
```

`runner.start` accepts:

- `html:` — render an inline HTML string (useful for tests and simple apps)
- `url:` — navigate to an explicit URL

When using `Lune.run` with `assets:`, the macro internally creates a `Runner` and passes the embedded asset server's URL — so both APIs end up in the same place.

---

## Single-instance enforcement

`lune dev` and `lune run` create a lock file for the app name. If you try to launch a second instance of the same app, the second process exits immediately. This mirrors the behavior of most desktop apps.

---

## Event system

The event bus is bidirectional. Crystal pushes to JS via `app.emit`; JS pushes to Crystal via `Events.emit` from `runtime.js`. Both sides share the same event name namespace and use symmetric `On/on` / `Once/once` / `Off/off` APIs.

```crystal
# Crystal → JS
app.async do
  loop do
    app.emit("tick", Time.utc.to_s)
    sleep 1.second
  end
end

# Crystal listening for JS events — dispatch heavy work to app.async
app.on("search") do |data|
  query = data["query"].as_s
  app.async { app.emit("results", run_search(query).map(&.to_h)) }
end
```

```js
// JS → Crystal
import { Events } from "../lunejs/runtime/runtime.js";

Events.on("results", (data) => renderResults(data));
Events.emit("search", { query: input.value });
```

Under the hood, `app.emit` calls `window.__lune.crystalEmit` (Crystal→JS); `Events.emit` calls the `__lune.jsEmit` WebView binding (JS→Crystal). See the [Events](./events) guide for the full API.
