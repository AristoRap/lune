# Changelog

## [0.3.3] - 2026-05-14

### Added

- Dev error overlay — when `lune dev` compilation fails, a dedicated error window opens showing the Crystal compiler output. The window is owned by the CLI, stays open while you edit, and closes automatically when the next build succeeds.

## [0.3.0] - 2026-05-13

### Breaking changes

- `Lune.run` signature changed — `app` is now the first positional argument and the block yields `Lune::Options` for window configuration instead of `Lune::App` for binding setup. Bindings must be registered on `app` before calling `Lune.run`.
- `App#bind`, `App#bind_async`, `App#bind_typed`, and `App#namespace` removed. Use `Lune::Bindable` (annotation-driven) or `App#bind(name:, namespace:, args:, return_type:, async:)` directly.
- JS namespace is now the Crystal class name, not a manually declared string. Method names are camelcased: `greet` → `Greet`, `slow_echo` → `SlowEcho`.

### Added

- `Lune::Runner` — extracted webview lifecycle; enables programmatic navigation via `runner.start(html:)` or `runner.start(url:)`
- `Lune::Options` — window options as a first-class object (`title`, `width`, `height`, `min_*`, `max_*`, `resizable`, `debug`, `on_navigate`, `on_close`)
- `Lune::BindingDef` — typed binding descriptor carrying namespace, argument types, and return type
- `-Dbuild_mode` compile flag — Crystal app runs in a pre-pass to generate `App.js` / `App.d.ts` before frontend bundling, so typed exports are available in production builds
- `App.d.ts` now contains precise TypeScript signatures derived from Crystal method annotations, not just `Promise<unknown>` stubs

### Changed

- `Lune::Bindable` uses the Crystal class name as the JS namespace; nested namespaces follow `::` (`Math::Trig` → `api.Math.Trig`)
- `Lune::Runtime` generates structured namespaced JS and typed `.d.ts` from `BindingDef` arrays
- `Lune::RuntimeBindings` returns `Array(BindingDef)` instead of registering directly on the bridge
- CLI commands reorganized under `LuneCLI::Commands` module; constants extracted to `constants.cr`
- `generate_bindings` moved inside `Build#run` so test doubles fully cover the build path

### Specs

- Reorganized under `spec/lune/` and `spec/lune_cli/` mirroring source layout
- 128 examples covering `App`, `Bridge`, `Runtime`, `RuntimeBindings`, `Runner`, and all CLI commands

## [0.2.4] - 2026-05-11

### Fixed

- `lune dev` now passes the configured `frontend.dir` to the compiled app via `LUNE_FRONTEND_DIR`, so `write_js` writes to the correct directory (e.g. `ui/lunejs/`) instead of the hardcoded `frontend/lunejs/`

### CI

- Release workflow — pushing a `v*` tag builds `lune-linux-x86_64`, `lune-darwin-arm64`, and `lune-darwin-x86_64` and attaches them to the GitHub release

### Internal

- Reorganize CLI internals

## [0.2.3] - 2026-05-11

### Fixed

- **Windows**: run the webview on a dedicated OS thread via `Fiber::ExecutionContext::Isolated` so Crystal's IO scheduler is not starved by the WebView2 C event loop (based on Crystal core team guidance)
- **Windows**: replace `LibC.flock` with cross-platform `flock_exclusive` — `flock(2)` is POSIX-only; the stdlib wrapper uses `LockFileEx` on Windows

### CI

- Windows runner downloads WebView2 SDK headers via NuGet before `shards install`
- Windows runs `--no-codegen` type-check; webview `.lib` linking is not supported in CI

## [0.2.2] - 2026-05-11

### Changed

- CLI is now fully config-driven via `lune.yml` — removed `--frontend-dir`, `--app-entry`, `--dev-cmd`, `--build-cmd`, and `--dev-url` flags from all commands
- Logger no longer duplicates Argy error output; timestamped logs only appear during runtime events (compilation, file watching, etc.)
- Doctor command hardened for config-driven operation

## [0.2.1] - 2026-05-10

### Added

- `lune.yml` project config for frontend toolchain — `app_entry`, `frontend.dir`, `frontend.install`, `frontend.build`, `frontend.dev.cmd`, `frontend.dev.url`

## [0.2.0] - 2026-04-XX

### Added

- Runtime JS API and TypeScript definitions generated from registered bindings
- Event bus — `app.emit()` pushes events from Crystal to the frontend
- `lune doctor` command — checks Crystal, Node, npm, shards, and frontend deps
- Single-instance lock for `lune dev` and `lune run`
- Command aliases (`d` for dev, `b` for build, `r` for run)

## [0.1.3] - 2026-04-XX

### Added

- Keyboard shortcuts injected via `wv.init` (copy/paste/undo/redo/select-all)

### Fixed

- Binding errors only show stack traces under `--debug`

## [0.1.2] - 2026-04-XX

### Fixed

- Pass `binding_names` to `Runtime.write_js` in dev mode

## [0.1.1] - 2026-04-XX

### Fixed

- Windows compatibility fixes

## [0.1.0] - 2026-04-XX

Initial release.
