# Lune Roadmap

## Now — v0.7.x

- [ ] Windows support
- [x] User-configurable menu bar — `opts.menu { }` / `app.update_menu` / `app.set_menu`
- [x] Context menus
- [ ] Multiple windows

## Next — Production-ready

These are the gaps that prevent Lune apps from shipping as standalone products.

- [x] Distribution packaging — `lune dist` outputs a DMG on macOS and an AppImage on Linux; Windows packaging pending
- [ ] Auto-updater — in-app update checks and installs driven by a manifest URL; Sparkle on macOS, equivalent on Linux/Windows
- [x] Deep links / custom URL scheme — register `myapp://` so the OS routes URLs into the running app; essential for OAuth redirect flows

## Backlog — Native APIs

Features the platform exposes that Lune doesn't yet surface.

- [ ] Global keyboard shortcuts — system-wide hotkeys that fire even when the window is not focused; common for tray-icon apps
- [ ] Shell / process execution — spawn child processes and stream stdout/stderr to the frontend
- [ ] File watching — monitor filesystem paths for changes and emit events to the frontend
- [x] Rich clipboard — image and HTML read/write beyond current text-only support
- [x] Drag-out — native drag of files from the WebView into the system (complement to existing drop-in)
- [ ] App icon support on Windows — `.ico` bundled into `lune build`

## Backlog — Architecture

Structural improvements that unlock whole categories of apps.

- [x] Main-thread safety for native UI — all AppKit (macOS) and GTK (Linux) calls now dispatch synchronously to the main thread when invoked from a background fiber, eliminating the intermittent `NSInternalInconsistencyException: nextEventMatchingMask` crash

- [ ] Plugin system — a Crystal shard interface (`Lune::Plugin`) with lifecycle hooks and runtime binding registration so community authors can publish Lune plugins
- [ ] Per-window capabilities — scope `include`/`exclude` lists to individual windows rather than globally (depends on multiple windows)
- [ ] Multiple webviews in one window — stack or embed multiple WebView panels within a single native window
- [ ] High-throughput IPC channel — ordered, low-latency data delivery for streaming and high-frequency progress events (complement to the event bus, which is not optimised for this)
- [x] Typed error propagation — Crystal exceptions in bindings arrive in JS as structured `Error` subclasses with type, message, and optional metadata rather than a raw string

## Backlog — DX & Templates

- [ ] Splash screen — show a configurable loading view while the Crystal runtime and frontend initialise
- [ ] Additional templates — Svelte, React + TypeScript
- [x] Notifications in production builds — `mac.sign` in `lune.yml` triggers `codesign` after `lune build`; runtime detects Team Identifier and routes to `UNUserNotificationCenter` or osascript accordingly

---

_v0.2 – v0.7.0 shipped: event bus, runtime JS/TS API (namespaced PascalCase objects), codegen bindings, dev error overlay, tray, file dialogs, drag-and-drop, window controls, notifications, screen info, app paths, clipboard (rich: text/HTML/image), window state persistence, capability allowlist (group-level), app icons, default menu bar, demo app (Vue 3 template), real async via OS threads, options API grouped into nested blocks, user-configurable menu bar, context menus, drag-out, deep links, distribution packaging (DMG + AppImage), code signing, notarization, LuneError typed rejections, capability architecture refactoring. See [CHANGELOG.md](CHANGELOG.md) for details._
