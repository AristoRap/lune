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
│                         ↑ events                        │  │
│                         │ app.emit(name, data)          │  │ binding call
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

When you call `app.install(MyModule.new)`, the generated `install` method fires. Each binding is registered with the `Bridge`, which wires a WebView binding callback — a JavaScript-callable function backed by native code.

Lune's own built-in capabilities (lifecycle, filesystem, clipboard, window controls, dialogs, tray, notifications, screen) are registered the same way — as `Installable` classes that call `app.bind` internally. There is no separate path for built-in vs user bindings.

### 4. JavaScript stub generation

Lune writes two files into `frontend/lunejs/`:

- `app/App.js` — one stub function per binding, grouped by namespace
- `app/App.d.ts` — TypeScript declarations with exact types derived from Crystal signatures

This happens automatically on `lune dev` startup and during `lune build` (before Vite runs).

### 5. The call

When frontend code calls `api.MyModule.greet("world")`:

1. The JS stub calls the WebView's native binding with the serialized arguments
2. The Bridge deserializes them and dispatches to the Crystal method
3. The return value is serialized as JSON and resolves the `Promise`

All binding calls return a `Promise` on the JavaScript side. Sync Crystal methods resolve immediately; `async: true` methods run in a Crystal fiber.

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
    ├── runtime.js   # quit, openURL, environment, on/once/off
    └── runtime.d.ts # TypeScript declarations
```

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

Crystal can push data to the frontend at any time via `app.emit`:

```crystal
spawn do
  loop do
    app.emit("tick", Time.utc.to_s)
    sleep 1.second
  end
end
```

Under the hood `emit` calls `window.__lune_emit`, which the runtime registers as a custom event dispatcher. The frontend listens with `on` / `once` from `runtime.js`.
