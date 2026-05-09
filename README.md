# Lune

[![Specs](https://github.com/AristoRap/lune/actions/workflows/specs.yml/badge.svg)](https://github.com/AristoRap/lune/actions/workflows/specs.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Crystal](https://img.shields.io/badge/crystal-%3E%3D%201.20.0-black?logo=crystal)](https://crystal-lang.org)

Build native desktop apps with Crystal and a web frontend.

Lune wraps a native WebView and lets you call Crystal code from JavaScript over a typed bridge — no servers, no IPC boilerplate. Think Wails or Tauri, but for Crystal.

## Prerequisites

- [Crystal](https://crystal-lang.org) >= 1.20.0
- [Node.js](https://nodejs.org) (for the frontend build)
- [Lune CLI](#cli) on your PATH (`make deploy` or `shards build && cp bin/lune /usr/local/bin/lune`)

## Installation

Add Lune to your `shard.yml`:

```yaml
dependencies:
  lune:
    github: aristorap/lune
    version: ~> 0.1
```

Then run:

```sh
shards install
```

## Quick start

```sh
lune init my_app
cd my_app
lune dev
```

`lune init` scaffolds a Crystal entry point and a Vite frontend. `lune dev` compiles your Crystal app and starts the Vite dev server together, with hot-reload on source changes.

## Crystal API

### `Lune.run`

```crystal
require "lune"

Lune.run(
  title:      "My App",
  assets:     "frontend/dist",   # embedded at compile time
  width:      1200,
  height:     800,
  min_width:  800,
  min_height: 600,
  debug:      false,
  on_load:    -> { puts "page loaded" },
  on_navigate: ->(url : String) { puts "navigated to #{url}" },
  on_close:   -> { puts "window closed" },
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

## CLI

```
lune init [APP_NAME]    Scaffold a new Lune app (--template vanilla|vue)
lune dev                Start Vite + Crystal with hot-reload
lune check              Type-check without building
lune build              Build frontend + compile Crystal binary
lune run                Launch the previously built artifact
```

Shared flags (apply to all commands):

```sh
--frontend-dir   Frontend directory (default: frontend)
--app-entry      Crystal entry file (default: src/main.cr)
--debug          Enable debug logging
```

### `lune build` output

```sh
lune build
# macOS  → build/bin/my_app.app
# Linux  → build/bin/my_app
```

The frontend is compiled with `npm run build` and embedded in the binary via Crystal macros — the artifact is a single self-contained file.

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
