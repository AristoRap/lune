# Lune Roadmap

## Production-ready/Windows support

The gaps that prevent Lune apps from shipping as standalone products.

- [ ] Auto-updater — in-app update checks and installs driven by a manifest URL; Sparkle on macOS, equivalent on Linux/Windows
- [ ] Windows runtime — blocked on **Crystal 1.21.0**. v0.10.0 + v0.11.0 added Win32 implementations for window/screen/dialog/clipboard-html/hotkeys/context-menu/notify/deep-link-cold-start, but Crystal 1.20.x can't compile a runnable binary on MSVC (`LibC::PidT` missing in `Process.initialize`; fixed in [crystal#16933](https://github.com/crystal-lang/crystal/pull/16933), shipping in 1.21). Once 1.21 lands, walk through [`website/guide/windows-checklist.md`](website/guide/windows-checklist.md) to verify each capability.
- [x] App icon support on Windows — `.ico` embedded into `lune build` via generated `.rc` + `rc.exe` (v0.11.0).

## Native APIs

Features the platform exposes that Lune doesn't yet surface.

- [ ] `autostart` capability — register the app to launch at login (LaunchAgent on macOS, `.desktop` on Linux)
- [ ] Reactive SQLite — `Sqlite.watch(db, sql, params, cb)` re-runs a query and pushes updated rows whenever the database is written; pairs with Stream for live Vue reactivity

## Architecture

Structural improvements that unlock whole categories of apps.

- [ ] Plugin system — a Crystal shard interface (`Lune::Plugin`) with lifecycle hooks and runtime binding registration so community authors can publish Lune plugins
- [ ] Per-window capabilities — scope `include`/`exclude` lists to individual windows rather than globally
- [ ] Multiple webviews in one window — stack or embed multiple WebView panels within a single native window
- [ ] `ext/native/windows/` shim parity — Win32 currently calls `user32`/`shell32`/`comdlg32`/etc. directly from `src/lune/native/*.cr` via `@[Link("…")]`, while macOS and Linux use `.m`/`.c` shims compiled into `ext/native/<platform>/*.o` linked behind a uniform `LibNativeFoo`. Direct FFI works (Tauri/Rust do the same on Win32) but the inconsistent pattern complicates per-capability branching. Refactor to add `ext/native/windows/*.cpp` shims compiled via `cl.exe` so every platform exposes the same `LibNativeFoo` interface.

## DX & Templates

- [ ] Splash screen — show a configurable loading view while the Crystal runtime and frontend initialise
- [ ] Additional templates — Svelte, React + TypeScript

---

_Shipped through v0.9.0: event bus, runtime JS/TS API (namespaced PascalCase objects), codegen bindings, dev error overlay, tray, file dialogs, drag-and-drop (in + drag-out), window controls, notifications (incl. production builds via codesign + UNUserNotificationCenter), screen info, app paths, rich clipboard (text/HTML/image), window state persistence, capability allowlist with cascading dep resolution, app icons (macOS/Linux), default and user-configurable menu bar, context menus, deep links / custom URL scheme, demo app (Vue 3 template), real async via OS threads with shared thread pool, options API grouped into nested blocks, distribution packaging (DMG + AppImage), code signing, notarization, typed error propagation (`LuneError`), capability architecture refactor, WebSocket IPC stream (bidirectional, high-throughput), shell / process execution (`Shell.run` + `Shell.spawn` + `Shell.kill` + `Shell.list` + `Shell.write` + `Shell.closeStdin`), file watching (kqueue/inotify with debounce), global hotkeys, SQLite capability, multiple windows (with cross-window capability propagation), KV store, frameless windows (`mac.full_size_content` + `mac.hide_title` + `mac.hide_traffic_lights` + `mac.transparent` + CSS drag zones), main-thread safety for native UI, menubar-only mode + unified tray click model (`toggle_window_on`, `on_right_click`, `Tray.popupMenu`, `auto_show`). See [CHANGELOG.md](CHANGELOG.md) for details._
