[![Specs](https://github.com/AristoRap/lune/actions/workflows/specs.yml/badge.svg)](https://github.com/AristoRap/lune/actions/workflows/specs.yml)
[![Version](https://img.shields.io/github/v/tag/AristoRap/lune?label=version)](https://github.com/AristoRap/lune/tags)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Crystal](https://img.shields.io/badge/crystal-%3E%3D%201.20.0-black?logo=crystal)](https://crystal-lang.org)

<div style="width: 100%; background: #0B0D14; border-radius: 12px;">
  <p align="center">
    <img src="assets/lune-logo.svg"  />
  </p>
</div>

# Lune

Build native desktop apps with Crystal and a web frontend.

Lune wraps a native WebView and lets you call Crystal code from JavaScript over a typed bridge — no servers, no IPC boilerplate. Think Wails or Tauri, but for Crystal.

> **v0.x notice:** Both the library and CLI APIs may change before 1.0. If you use this now, expect occasional breaking changes.

## Documentation

Full docs live at the project website (run `npm run docs:dev` locally from the repo):

- [Getting Started](website/getting-started.md)
- [How It Works](website/guide/how-it-works.md)
- [Bindings](website/guide/bindings.md)
- [Assets & Build](website/guide/assets.md)
- [Error Handling](website/guide/error-handling.md)
- [Events](website/guide/events.md)
- [TypeScript](website/guide/typescript.md)
- [Window Configuration](website/guide/window.md)
- [CLI Reference](website/cli-reference.md)
- [Configuration (lune.yml)](website/configuration.md)

## Quick start

```sh
lune init my_app
cd my_app
lune dev
```

Pre-built CLI binaries are on the [releases page](https://github.com/AristoRap/lune/releases). Or build from source: `make setup && make deploy`.

## Platform support

| Platform | Dev | Build |
|----------|-----|-------|
| macOS    | ✅  | ✅    |
| Linux    | ✅  | ✅    |
| Windows  | ⚠️ requires manual setup | ⚠️ untested |

### Windows

The `naqvis/webview` postinstall script is Unix-only. Before running `shards install`, manually set up WebView2:

1. Download the [WebView2 NuGet package](https://www.nuget.org/packages/Microsoft.Web.WebView2) and extract `build/native/include/WebView2.h` into `lib/webview/ext/`.
2. Build `webview.dll` and `webview.lib` with MSVC `cl.exe` against that header.
3. Copy `webview.dll`, `webview.lib`, and `WebView2Loader.dll` into a directory on `CRYSTAL_LIBRARY_PATH`.
4. Run `shards install --skip-postinstall`.

The webview event loop must own a dedicated OS thread on Windows. Lune uses `Fiber::ExecutionContext::Isolated` for this. **Untested on real hardware** — feedback welcome.

## Development

```sh
make setup   # shards install + npm install
make test    # crystal spec
make deploy  # build release binary → /usr/local/bin/lune
```

## Contributing

1. Fork it (<https://github.com/aristorap/lune/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Add specs for your changes (`crystal spec`)
4. Commit and push and open a Pull Request

## Contributors

- [Aristotelis Rapai](https://github.com/aristorap) — creator and maintainer

## License

MIT
