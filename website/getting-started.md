# Getting Started

## Prerequisites

- **Crystal** >= 1.20.1 — [install](https://crystal-lang.org/install/)
- **Node.js** >= 18 and **npm** — [install](https://nodejs.org/)
- **shards** — ships with Crystal

::: warning Experimental Crystal flags required
Lune compiles with `-Dpreview_mt -Dexecution_context`. These flags enable Crystal's multi-threading execution context API, which Lune uses to run `async:` bindings on real OS threads without blocking the native GUI event loop.

The `lune` CLI passes both flags automatically for `lune dev` and `lune build`. If you ever invoke `crystal build` directly, add both flags yourself:

```sh
crystal build src/main.cr -Dpreview_mt -Dexecution_context -o build/my_app
```

**`spawn` does not work for background tasks.** The native event loop owns the main thread, so fibers in the default cooperative context are never scheduled while the window is open. Use `app.async` for any long-running background work:

```crystal
app.async do
  loop do
    app.emit("tick", Time.utc.to_rfc3339)
    sleep 1.second
  end
end
```

:::

**macOS only:** Xcode Command Line Tools are required for the native WebView headers.

**Linux only:** Install WebKit development headers:

```sh
# Ubuntu / Debian
sudo apt install libwebkit2gtk-4.1-dev

# Fedora
sudo dnf install webkit2gtk4.1-devel
```

---

## Install the CLI

Pre-built binaries are attached to each [GitHub release](https://github.com/AristoRap/lune/releases):

| Platform              | File                |
| --------------------- | ------------------- |
| macOS (Apple Silicon) | `lune-darwin-arm64` |
| Linux x86_64          | `lune-linux-x86_64` |

> **macOS Intel (x86_64):** No pre-built binary is available — the GitHub Actions Intel runner is currently unreliable. Build from source instead (see below).

Download the binary for your platform, make it executable, and put it on your PATH:

```sh
chmod +x lune-darwin-arm64
mv lune-darwin-arm64 /usr/local/bin/lune
```

**Or build from source:**

```sh
git clone https://github.com/aristorap/lune
cd lune
make setup   # shards install
make deploy  # build release binary → /usr/local/bin/lune
```

---

## Add Lune to a project

Add it to your `shard.yml`:

```yaml
dependencies:
  lune:
    github: AristoRap/lune
    version: ~> 0.7.0
```

Then install:

```sh
shards install
```

---

## Create a new app

```sh
lune init my_app                          # defaults to vanilla template
lune init my_app --template vue           # Vue 3 + Vite
lune init my_app --template vanilla       # Vanilla JS + Vite
```

This scaffolds a ready-to-run project:

```
my_app/
├── src/
│   └── main.cr          # Crystal entry point
├── frontend/            # Your Vite frontend
│   ├── src/
│   │   └── main.{js,ts}
│   ├── index.html
│   └── vite.config.{js,ts}
├── lune.yml             # Project configuration
└── shard.yml
```

---

## Start the dev server

```sh
cd my_app
lune dev
```

This starts both your Vite dev server and the Crystal backend. The app opens in a native window. Saving frontend files hot-reloads the UI; saving Crystal files triggers a recompile and refresh.

---

## Call Crystal from JavaScript

Open `src/main.cr`. You'll find a module that includes `Lune::Bindable`:

```crystal
require "lune"

class GreetModule
  include Lune::Bindable

  @[Lune::Bind]
  def greet(name : String) : String
    "Hello, #{name}!"
  end
end

app = Lune::App.new
app.install(GreetModule.new)

Lune.run(app, assets: "frontend/dist") do |opts|
  opts.title = "My App"
  opts.width = 1200
  opts.height = 800
end
```

In your frontend, import the generated API and call it:

```js
import api from "../lunejs/app/App.js";

const message = await api.GreetModule.greet("world");
console.log(message); // "Hello, world!"
```

---

## Build for production

```sh
lune build
```

Or with optimizations:

```sh
lune build --release
```

This builds the frontend with Vite, then compiles the Crystal binary with the frontend embedded via the `assets:` argument in your `Lune.run` call. The output is a single self-contained executable in `build/`.

> **Note:** The `assets: "frontend/dist"` argument in `Lune.run` is what tells Lune to embed the frontend into the binary. Without it, the built app will have no frontend to serve. See [Assets & Build](./guide/assets) for details.

---

## Demo app

The repository ships with a full showcase in `demo/` — a Vue 3 app that exercises every part of the Lune API in one window:

| Section      | What it shows                                                                                   |
| ------------ | ----------------------------------------------------------------------------------------------- |
| Bindings     | `@[Lune::Bind]` — calling Crystal methods from JS as async functions                            |
| Events       | Live clock (Crystal → JS), ping/pong roundtrip with latency, async file-progress                |
| System       | `System.environment()`, `Screen.info()`, native notifications                                |
| Clipboard    | `Clipboard.read/write`, `Clipboard.readHtml/writeHtml`, `Clipboard.readImage/writeImage`        |
| Window       | `Window.minimize`, `Window.maximize`, `Window.center`, `Window.setTitle`, `Window.setSize`      |
| Dialogs      | File pickers (`Dialogs.openFile`, `openFiles`, `openDir`, `saveFile`) and message dialogs       |
| Tray         | Status-bar icon with click and menu-item event log                                              |
| Context Menu | `ContextMenu.set` / `clear` / `onSelect` — native right-click menu with item selection          |
| Drag Out     | `DragOut.start(paths)` — drag local files out of the window into Finder or other apps           |
| Deep Links   | `url_schemes` config, `DeepLink.onDeepLink(cb)` — receive OS-routed custom URL scheme links     |
| Capabilities | Runtime capability filtering (`include` / `exclude`) with live binding list                     |

Run it from the repo root:

```sh
cd demo
lune dev
```

The frontend lives in `demo/frontend/src/` and is structured as a real Vue project — views, components, composables, and a `useLuneEvent` composable that handles `on`/`off` cleanup automatically on unmount. It is a good starting point to copy patterns from.

---

## What's next

- Learn how the Crystal ↔ JavaScript bridge works: [How It Works](./guide/how-it-works)
- Explore the full binding API: [Bindings](./guide/bindings)
- See all CLI commands: [CLI Reference](./cli-reference)
- Understand `lune.yml`: [Configuration](./configuration)
