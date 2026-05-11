# Changelog

## [0.2.4] - 2026-05-X

- Reorganize CLI internals
- Ensure we pass the configured frontend_dir to dev for write_js calls

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
