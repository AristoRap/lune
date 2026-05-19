# Lune Roadmap

## Now

- [x] High-throughput IPC stream — WebSocket-backed ordered delivery for streaming and high-frequency events
- [x] Shell / process execution — spawn child processes and stream stdout/stderr to the frontend via Stream
- [x] Global keyboard shortcuts — system-wide hotkeys that fire even when the window is not focused
- [x] File watching — monitor filesystem paths for changes and emit events to the frontend

## Next — Production-ready

These are the gaps that prevent Lune apps from shipping as standalone products.

- [x] Distribution packaging — `lune dist` outputs a DMG on macOS and an AppImage on Linux; Windows packaging pending
- [x] Deep links / custom URL scheme — register `myapp://` so the OS routes URLs into the running app; essential for OAuth redirect flows
- [ ] Auto-updater — in-app update checks and installs driven by a manifest URL; Sparkle on macOS, equivalent on Linux/Windows
- [ ] Windows support
- [ ] App icon support on Windows — `.ico` bundled into `lune build`

## Backlog — Native APIs

Features the platform exposes that Lune doesn't yet surface.

- [x] Rich clipboard — image and HTML read/write beyond current text-only support
- [x] Drag-out — native drag of files from the WebView into the system (complement to existing drop-in)
- [ ] SQLite — embedded database access via Crystal's `sqlite3` shard with a typed JS bridge; pairs naturally with the Stream for reactive data flows
- [ ] Multiple windows

## Backlog — Architecture

Structural improvements that unlock whole categories of apps.

- [x] Main-thread safety for native UI — all AppKit (macOS) and GTK (Linux) calls dispatch synchronously to the main thread when invoked from a background fiber
- [x] Typed error propagation — Crystal exceptions arrive in JS as structured `LuneError` subclasses with type, message, and optional metadata
- [ ] Plugin system — a Crystal shard interface (`Lune::Plugin`) with lifecycle hooks and runtime binding registration so community authors can publish Lune plugins
- [ ] Per-window capabilities — scope `include`/`exclude` lists to individual windows rather than globally (depends on multiple windows)
- [ ] Multiple webviews in one window — stack or embed multiple WebView panels within a single native window

## Backlog — DX & Templates

- [x] Notifications in production builds — `mac.sign` in `lune.yml` triggers `codesign`; runtime detects Team Identifier and routes to `UNUserNotificationCenter` or osascript accordingly
- [ ] Splash screen — show a configurable loading view while the Crystal runtime and frontend initialise
- [ ] Additional templates — Svelte, React + TypeScript

---

_v0.2 – v0.9.0 shipped: event bus, runtime JS/TS API (namespaced PascalCase objects), codegen bindings, dev error overlay, tray, file dialogs, drag-and-drop, window controls, notifications, screen info, app paths, clipboard (rich: text/HTML/image), window state persistence, capability allowlist (group-level), app icons, default menu bar, demo app (Vue 3 template), real async via OS threads, options API grouped into nested blocks, user-configurable menu bar, context menus, drag-out, deep links, distribution packaging (DMG + AppImage), code signing, notarization, LuneError typed rejections, capability architecture refactoring, WebSocket IPC stream (bidirectional, high-throughput), shell / process execution (Shell.run + Shell.spawn + Shell.kill). See [CHANGELOG.md](CHANGELOG.md) for details._
