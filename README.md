# Lune

[![Specs](https://github.com/AristoRap/lune/actions/workflows/specs.yml/badge.svg)](https://github.com/AristoRap/lune/actions/workflows/specs.yml)
[![Version](https://img.shields.io/github/v/tag/AristoRap/lune?label=version)](https://github.com/AristoRap/lune/tags)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Crystal](https://img.shields.io/badge/crystal-%3E%3D%201.20.0-black?logo=crystal)](https://crystal-lang.org)

Build native desktop apps with Crystal and a web frontend.

Lune wraps a native WebView and lets you call Crystal code from JavaScript over a typed bridge — no servers, no IPC boilerplate. Think Wails or Tauri, but for Crystal.

## Prerequisites

- [Crystal](https://crystal-lang.org) >= 1.20.0
- [Node.js](https://nodejs.org) (for the frontend build)
- The Lune CLI — see below

## Platform support

| Platform | Dev (`lune dev`)         | Build (`lune build`)    |
| -------- | ------------------------ | ----------------------- |
| macOS    | ✅                       | ✅                      |
| Linux    | ✅                       | ✅                      |
| Windows  | ⚠️ requires manual setup | ⚠️ untested (see below) |

### Windows

Windows support is incomplete. The development workflow can be made to work with manual steps, but production builds are blocked by a fundamental Crystal-on-Windows limitation.

#### Manual setup required: WebView2

The `naqvis/webview` shard's postinstall script is Unix-only. Before running `shards install`, fetch the WebView2 SDK manually:

1. Download the [WebView2 NuGet package](https://www.nuget.org/packages/Microsoft.Web.WebView2) and extract `build/native/include/WebView2.h` into `lib/webview/ext/`.
2. Build `webview.dll` and `webview.lib` with MSVC `cl.exe` against that header.
3. Copy `webview.dll`, `webview.lib`, and `WebView2Loader.dll` into a directory listed in `CRYSTAL_LIBRARY_PATH`.
4. Then run: `shards install --skip-postinstall` (Lune passes this flag automatically on Windows).

#### Webview thread isolation

`wv.run()` blocks its calling thread inside WebView2's native message loop. On Windows this means the C event loop must own a dedicated OS thread, otherwise Crystal's IO scheduler never gets CPU time and any concurrent work (HTTP server, file watcher, etc.) stalls.

Lune addresses this with `Fiber::ExecutionContext::Isolated`, which runs the entire webview setup and event loop on its own thread.
Thanks to Crystal core team for the suggestion on Reddit — see the [ExecutionContext API docs](https://crystal-lang.org/api/1.20.1/Fiber/ExecutionContext.html).

**This fix is untested on real Windows hardware.** The project is developed on macOS and Windows CI only runs a type-check (`--no-codegen`) because webview `.lib` linking is not supported in the CI environment. If you have a Windows machine and can test this, feedback and bug reports are very welcome.

## Disclaimer

While in v0.x, both the Lune lib and LuneCLI are subjected to changes.
I don't have any major re-writes planned, but if you use this now, please keep in mind that the APIs and features will possibly change.

## Getting the CLI

The CLI is not distributed as a pre-built binary. Clone this repo and either install it globally or run it directly:

```sh
git clone https://github.com/aristorap/lune
cd lune
make setup        # shards install

make deploy       # build release binary → /usr/local/bin/lune

# or run without installing (runs relative to your path):
crystal run bin/lune.cr -- <command>
```

## Quick start

With the CLI on your PATH:

```sh
lune init my_app
cd my_app
lune dev
```

`lune init` scaffolds a Crystal entry point, a Vite frontend, and a `lune.yml` project config. `lune dev` compiles your Crystal app and starts the frontend dev server together, with hot-reload on source changes. See [examples/main.cr](examples/main.cr) for what the generated entry point looks like.

## Adding Lune to an existing project

Add it to your `shard.yml`:

```yaml
dependencies:
  lune:
    github: aristorap/lune
    version: ~> 0.2
```

```sh
shards install
```

You still need the CLI for `lune dev` and `lune build` — see [Getting the CLI](#getting-the-cli).

## Crystal API

### `Lune.run`

```crystal
require "lune"

Lune.run(
  title:       "My App",
  assets:      "frontend/dist",   # embedded at compile time
  width:       1200,
  height:      800,
  min_width:   800,
  min_height:  600,
  debug:       false,
  on_load:     -> { puts "page loaded" },
  on_navigate: ->(url : String) { puts "navigated to #{url}" },
  on_close:    -> { puts "window closed" },
) do |app|
  # register bindings here
end
```

**Navigation priority** (first match wins):

1. `html:` — inline HTML string
2. `url:` — explicit URL
3. `LUNE_DEV_URL` env var — set automatically by `lune dev`
4. `assets:` — directory embedded at compile time, served over a local HTTP server

### Binding Crystal to JavaScript

**`bind_typed`** — single typed argument, return is auto-converted:

```crystal
app.bind_typed("greet", String) { |msg| "Hello, #{msg}!" }
```

**`bind`** — raw `Array(JSON::Any)` args, for multiple positional arguments:

```crystal
app.bind("add") do |args|
  a = args[0].as_i
  b = args[1].as_i
  JSON::Any.new((a + b).to_i64)
end
```

**`bind_typed` with a struct** — named arguments via a JSON-serializable struct:

```crystal
struct AddArgs
  include JSON::Serializable
  getter a : Int32
  getter b : Int32
end

app.bind_typed("add", AddArgs) { |args| args.a + args.b }
```

**`bind_async`** — same raw signature, runs the block off the main thread:

```crystal
app.bind_async("slow_echo") do |args|
  sleep 1.second
  JSON::Any.new("(delayed) #{args[0].as_s}")
end
```

### Namespaces

Group related bindings under a dot-separated prefix:

```crystal
app.namespace("counter") do |counter|
  counter.bind_typed("inc", Int32) { |n| n + 1 }
  counter.bind_typed("dec", Int32) { |n| n - 1 }
end
```

Namespaces compose: `math.trig.sin` registers as `math.trig.sin` in JS.

### Events (Crystal → JS)

Push events from Crystal to the frontend at any time — from a background fiber, a timer, or after a binding returns:

```crystal
# emit with any JSON-serializable data
app.emit("status", "ready")
app.emit("progress", {step: 3, total: 10})

# namespaced — event name is prefixed automatically
app.namespace("hash") do |h|
  h.bind_async("compute") do |args|
    result = compute(args[0].as_s)
    h.emit("done", result)   # fires as "hash.done"
    JSON::Any.new(result)
  end
end

# fire from a background fiber
spawn do
  loop do
    sleep 1.second
    app.emit("tick", Time.utc.to_s)
  end
end
```

### Plugin modules

Extract binding sets into reusable `Installable` modules:

```crystal
class GreetModule
  include Lune::Installable

  def install(app : Lune::App)
    app.bind_typed("greet", String) { |msg| "Hello, #{msg}!" }
  end
end

Lune.run(title: "My App", assets: "frontend/dist") do |app|
  app.install(GreetModule.new)
end
```

## JavaScript API

Lune generates `frontend/lunejs/app/App.js` from your registered bindings. Import `api` for a fully dynamic proxy, or import named stubs directly:

```js
import api from "../lunejs/app/App.js";

// dynamic proxy — any registered binding works
const msg = await api.greet("world");
const next = await api.counter.inc(0);

// named stub — same call, IDE-autocompletable
import { greet } from "../lunejs/app/App.js";
const msg = await greet("world");
```

All bindings return `Promise`. Exceptions thrown in Crystal reject the promise.

### Runtime functions

`runtime.js` also exports built-in system functions:

```js
import { quit, openURL, environment } from "../lunejs/runtime/runtime.js";

await quit(); // terminate the app
await openURL("https://example.com"); // open in system browser
const env = await environment(); // { os, arch, debug }
```

`environment()` returns a `LuneEnvironment` object:

```ts
interface LuneEnvironment {
  os: "darwin" | "linux" | "windows";
  arch: string; // "arm64" | "x86_64"
  debug: boolean;
}
```

### Listening to events from Crystal

Import `on`, `once`, or `off` from `runtime.js` to subscribe to events emitted by `app.emit`:

```js
import { on, once, off } from "../lunejs/runtime/runtime.js";

// persistent listener
on("status", (data) => console.log(data));

// fires once then removes itself
once("tick", (data) => console.log("first tick:", data));

// remove a specific listener
const handler = (data) => updateUI(data);
on("progress", handler);
off("progress", handler);

// remove all listeners for an event
off("progress");
```

### TypeScript

Lune generates `.d.ts` files alongside every JS file it writes:

- `runtime.d.ts` — fully typed declarations for all runtime functions and the `LuneEnvironment` interface
- `App.d.ts` — name stubs (`Promise<unknown>`) for each registered binding; tells the IDE which calls exist

Binding argument and return types require `lune generate` (see roadmap), which reads Crystal annotations to produce precise types.

## lune.yml

`lune init` generates a `lune.yml` in your project root. All keys are optional — omitted values fall back to their defaults.

```yaml
name: my_app
app_entry: src/main.cr # default: src/main.cr
frontend:
  dir: frontend # default: frontend
  install: npm install # default: npm install
  build: npm run build # default: npm run build
  dev:
    cmd: npm run dev # default: npm run dev
    url: http://localhost:5173
```

All keys are optional — omitted values fall back to their defaults. `lune.yml` is the single source of truth for project paths and toolchain commands; there are no CLI flag equivalents.

## CLI

```
lune init [APP_NAME]    Scaffold a new Lune app (--template vanilla|vue)
lune dev   (alias: d)   Start frontend dev server + Crystal with hot-reload
lune check              Type-check without building
lune build (alias: b)   Build frontend + compile Crystal binary
lune build --release    Build with Crystal --release optimizations
lune run   (alias: r)   Launch the previously built artifact
lune doctor             Check Crystal, Node, npm, shards, and frontend deps
```

`lune dev` and `lune run` both enforce single-instance at the CLI level — a second invocation for the same app entry exits immediately with an error rather than spawning a duplicate window.

Flags:

```sh
--debug     Enable debug logging (all commands)
--release   Build with Crystal --release optimizations (lune build only)
```

All project paths and toolchain commands (`app_entry`, `frontend_dir`, `dev_cmd`, `build_cmd`, `dev_url`) are configured in `lune.yml`, not via CLI flags.

### `lune build` output

```sh
lune build
# macOS  → build/bin/my_app.app
# Linux  → build/bin/my_app
```

The frontend is compiled via `build_cmd` (set in `lune.yml`) and embedded in the binary via Crystal macros — the artifact is a single self-contained file.

## Development

```sh
make setup             # shards install + npm install
make test              # crystal spec
make deploy            # build release binary + copy to /usr/local/bin
```

## Contributing

1. Fork it (<https://github.com/aristorap/lune/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Add specs for your changes (`crystal spec`)
4. Commit and push (`git commit -am 'Add feature' && git push origin my-new-feature`)
5. Open a Pull Request

## Contributors

- [Aristotelis Rapai](https://github.com/aristorap) — creator and maintainer

## License

MIT
