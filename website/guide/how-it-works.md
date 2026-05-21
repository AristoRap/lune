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
│  app.events.emit() · app.events.on()  ↔  emit() · on()  │  │ binding call
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

Lune's own built-in capabilities (system, filesystem, clipboard, window controls, dialogs, tray, notifications, screen) are registered the same way — as `Installable` classes. There is no separate path for built-in vs user bindings.

### 4. JavaScript stub generation

Lune writes four files into `frontend/lunejs/`:

- `app/App.js` — one stub function per user binding, grouped by namespace
- `app/App.d.ts` — TypeScript declarations with exact types derived from Crystal signatures
- `runtime/runtime.js` — built-in functions (`System.quit`, `System.openUrl`, `Events.on`, `Events.emit`, …)
- `runtime/runtime.d.ts` — TypeScript declarations for runtime functions

This happens automatically on `lune dev` startup and during `lune build` (before Vite runs).

### 5. The call

When frontend code calls `api.MyModule.greet("world")`:

1. The JS stub calls the WebView's native binding with the serialized arguments
2. The Bridge deserializes them and dispatches to the Crystal method
3. The return value is serialized as JSON and resolves the `Promise`

All binding calls return a `Promise` on the JavaScript side. Sync Crystal methods resolve inline on the webview thread (see [Threading model](#threading-model)); `async: true` methods run on the `lune-async` `Parallel` pool, so `sleep`, channels, and blocking IO all work without freezing the UI.

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
    ├── runtime.js   # runtime, System/Filesystem/Clipboard...
    └── runtime.d.ts # TypeScript declarations
```

---

## Threading model

Lune balances three constraints: the native UI toolkits (AppKit / GTK / WebView2) are single-threaded by design, Crystal's scheduler needs a non-blocked OS thread to dispatch fibers, and OS callbacks (SIGCHLD, WM_HOTKEY, kqueue/inotify, accept loops) want their own threads to avoid starving the UI. The runtime spins up several `Fiber::ExecutionContext` instances to satisfy all three.

### The webview thread

The thread that runs the WebView event loop — i.e. that's blocked inside `wv.run`. Sync binding callbacks and `app.events.on` handlers fire on this thread.

| Platform     | Webview thread is…                                                                                        |
| ------------ | --------------------------------------------------------------------------------------------------------- |
| macOS, Linux | The **main OS thread** (Cocoa and GTK refuse to run their event loop elsewhere)                           |
| Windows      | A dedicated `Isolated` thread named `webview`. The main thread parks on a channel waiting for it to exit. |

On Unix, this means the main thread is permanently occupied by Cocoa/GTK once `wv.run` is called, and the **default Crystal scheduler is starved** — `spawn` and the signal-loop fiber never get to run. On Windows the main thread stays free; `spawn` works there, but it's still cleaner to use Lune's pools so behaviour is portable.

### Where each kind of work runs

| Context                                  | Runs on                                                   | Notes                                                    |
| ---------------------------------------- | --------------------------------------------------------- | -------------------------------------------------------- |
| Sync binding callbacks (`@[Lune::Bind]`) | Webview thread                                            | Keep fast — blocks the UI while running                  |
| `async: true` binding callbacks          | `lune-async` `Parallel` pool (`System.cpu_count` threads) | Full scheduler: `sleep`, channels, blocking IO all work  |
| `app.events.on` handlers                 | Webview thread                                            | Same as sync bindings; offload heavy work to `app.async` |
| `app.async { }` tasks                    | `lune-tasks` `Parallel` pool (`System.cpu_count` threads) | Use for timers, pollers, anything long-running           |

### Dedicated `Isolated` threads (one OS thread each, opt-in by capability)

| Thread name          | When active                                 | What it does                                                                                                                                                                                                                                                                                             |
| -------------------- | ------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `webview`            | Windows always                              | Drives the WebView2 event loop, freeing the main thread for the Crystal scheduler                                                                                                                                                                                                                        |
| `lune-sigchld-pump`  | macOS + Linux always                        | Polls `SignalChildHandler` every 10 ms so `Process.run`/`Shell.spawn` don't hang while the main thread is in Cocoa/GTK                                                                                                                                                                                   |
| `lune-hotkeys`       | Hotkeys capability active                   | macOS Carbon `RegisterEventHotKey`, Linux X11 `XGrabKey`, Windows `RegisterHotKey` + `WM_HOTKEY` pump                                                                                                                                                                                                    |
| `lune-tray`          | Tray capability active on Windows           | Owns a message-only HWND, drains `WM_APP+1` notifications from `Shell_NotifyIconW`, and runs the menu op queue (macOS / Linux drive the tray on the existing AppKit / GTK main loop, no extra thread)                                                                                                    |
| `lune-file-watch`    | FileWatch on macOS + Linux                  | macOS kqueue / Linux inotify event loop (not spawned on Windows — capability is platform-filtered there)                                                                                                                                                                                                 |
| `lune-deep-link-ipc` | DeepLink capability on Linux                | Unix-socket accept loop for warm-start URL forwarding                                                                                                                                                                                                                                                    |
| `lune-stream`        | Stream capability on macOS / Linux          | 2-thread `Parallel` pool that owns the WebSocket server's `bind` + `listen`. On Win32, Stream instead spawns the bind+listen pair via `::spawn` on the default context to keep accept completions on the right IOCP — no dedicated thread.                                                               |
| `lune-assets`        | Embedded-asset HTTP server on macOS / Linux | Isolated accept loop on top of a 2-thread `lune-assets-pool` `Parallel` pool for per-connection request handling. On Win32, Assets::Server spawns bind+listen via `::spawn` on the default context (same IOCP-affinity reason as Stream — separating the two contexts parks accept completions forever). |

### Rules of thumb

- **Never block in a sync binding or `app.events.on` handler.** It freezes the UI for the duration. Move work to `app.async { … }` or mark the binding `async: true`.
- **`spawn` is unreliable** across platforms — works on Windows where the main thread isn't busy, doesn't on Unix where it's parked in Cocoa/GTK. Use `app.async` for portability.
- **`Fiber::ExecutionContext::Isolated` is the right primitive for capabilities** that own an OS resource (a poll loop, an accept loop, a message pump) and need to stay responsive even when the rest of the app is blocked.
- **Main-thread-only native calls** (NSStatusItem, GTK widget creation, etc.) are handled inside Lune's `Native::*` modules — capabilities don't have to think about marshaling.

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

The event bus is bidirectional. Crystal pushes to JS via `app.events.emit`; JS pushes to Crystal via `Events.emit` from `runtime.js`. Both sides share the same event name namespace and use symmetric `on`, `once`, `off` APIs.

```crystal
# Crystal → JS
app.async do
  loop do
    app.events.emit("tick", Time.utc.to_s)
    sleep 1.second
  end
end

# Crystal listening for JS events — dispatch heavy work to app.async
app.events.on("search") do |data|
  query = data["query"].as_s
  app.async { app.events.emit("results", run_search(query).map(&.to_h)) }
end
```

```js
// JS → Crystal
import { Events } from "../lunejs/runtime/runtime.js";

Events.on("results", (data) => renderResults(data));
await Events.emit("search", { query: input.value });
```

Under the hood, `app.events.emit` calls `window.__lune.crystalEmit` (Crystal→JS); `Events.emit` calls the `__lune.jsEmit` WebView binding (JS→Crystal). See the [Events](./events) guide for the full API.
