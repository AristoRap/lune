# Lune Roadmap

## Now — v0.6.x

- [ ] Windows support
- [x] User-configurable menu bar — `opts.menu { }` / `app.update_menu` / `app.set_menu`
- [ ] Context menus
- [ ] Multiple windows

## Backlog

- [ ] App icon support on Windows — `.ico` bundled into `lune build`
- [ ] Additional templates: Svelte, React+TS
- [ ] Notifications in production builds — `UNUserNotificationCenter` requires a bundle identifier; silently dropped when running as a raw binary from `lune build`

---

_v0.2 – v0.6.0 shipped: event bus, runtime JS/TS API, codegen bindings, dev error overlay, tray, file dialogs, drag-and-drop, window controls, notifications, screen info, app paths, clipboard, window state persistence, capability allowlist, app icons, default menu bar, example app, real async via OS threads, options API grouped into nested blocks, user-configurable menu bar. See [CHANGELOG.md](CHANGELOG.md) for details._
