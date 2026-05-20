[![Specs](https://github.com/AristoRap/lune/actions/workflows/specs.yml/badge.svg)](https://github.com/AristoRap/lune/actions/workflows/specs.yml)
[![Version](https://img.shields.io/github/v/tag/AristoRap/lune?label=version)](https://github.com/AristoRap/lune/tags)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Crystal](https://img.shields.io/badge/crystal-%3E%3D%201.20.1-black?logo=crystal)](https://crystal-lang.org)

<div style="width: 100%; background: #0B0D14; border-radius: 12px;">
  <p align="center">
    <img src="assets/lune-logo.svg"  />
  </p>
</div>

# Lune

Build native desktop apps with Crystal and a web frontend.

Lune wraps a native WebView and lets you call Crystal code from JavaScript over a typed bridge — no servers, no IPC boilerplate. Think Wails or Tauri, but for Crystal.

> **v0.x notice:** Both the library and CLI APIs may change before 1.0. If you use this now, expect occasional breaking changes.

> **Experimental Crystal flags:** Lune requires `-Dpreview_mt -Dexecution_context` at compile time. The `lune` CLI passes these automatically. If you compile your app manually (`crystal build`), you must include both flags. These unlock Crystal's multi-threading execution context API — the mechanism Lune uses to run `async:` bindings on real OS threads without blocking the native GUI event loop.

## Documentation

Full docs live at the project `website` folder

- visit [Lune Docs](https://aristorap.github.io/lune/), or
- run `npm run docs:dev` locally from the repo (also, `make web`)

## Quick start

```sh
lune init my_app              # vanilla JS + Vite
lune init my_app --template vue  # Vue 3 + Vite
cd my_app
lune dev
```

Pre-built CLI binaries are on the [releases page](https://github.com/AristoRap/lune/releases). Or build from source: `make setup && make deploy`.

The `demo/` directory in this repo is a full showcase of the Lune API — bindings, events, system calls, file dialogs, tray, and more — built with the Vue 3 template. Run it with `cd demo && lune dev`.

## Platform support

| Platform | Dev | Build | Notes                                                                                                                 |
| -------- | --- | ----- | --------------------------------------------------------------------------------------------------------------------- |
| macOS    | ✅  | ✅    | Native AppKit                                                                                                         |
| Linux    | ✅  | ✅    | GTK + WebKit2GTK                                                                                                      |
| Windows  | 🛑  | 🛑    | Win32 code is merged, but full `crystal build` is blocked on Crystal 1.21+ — see [WINDOWS_SETUP.md](WINDOWS_SETUP.md) |

### Windows

The Win32 implementations for window basics, screen, dialog, clipboard HTML, hotkeys, context menu, notifications (PowerShell toast), and deep-link cold-start are all in the tree as of v0.11.0. What's missing is a Crystal compiler that can actually build a runnable binary:

- **Crystal 1.20.2** (current release) hits `undefined constant LibC::PidT` during codegen of `Process.initialize` ([crystal#16929](https://github.com/crystal-lang/crystal/issues/16929)).
- **PR [crystal#16933](https://github.com/crystal-lang/crystal/pull/16933)** merged on master, **targeted for 1.21.0** — not in any released Crystal yet.

So until Crystal 1.21 ships, Windows is **blocked on upstream**. Type-check via `crystal build --no-codegen` passes (CI exercises this); a real binary doesn't. See [WINDOWS_SETUP.md](WINDOWS_SETUP.md) for the full setup walkthrough you can use once 1.21 lands, plus the per-capability checklist at [website/guide/windows-checklist.md](website/guide/windows-checklist.md).

## Development

```sh
make setup   # shards install + npm install
make test    # crystal spec
make deploy  # build release binary → /usr/local/bin/lune
```

> **Windows:** Run the underlying commands directly (`shards install`, `shards build --release`, etc.).

## Contributing

1. Fork it (<https://github.com/aristorap/lune/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Add specs for your changes (`crystal spec`)
4. Commit and push and open a Pull Request

## Contributors

- [Aristotelis Rapai](https://github.com/aristorap) — creator and maintainer

## License

MIT
