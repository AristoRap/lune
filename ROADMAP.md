# Lune Roadmap Ideas

## v0.2 — Developer experience

- [ ] Events system: `app.emit("event", data)` from Crystal → `window.dispatchEvent(CustomEvent)` in JS (pure `wv.eval`, no C)
- [ ] Additional templates: Svelte, React+TS (TS templates also generate `.d.ts` alongside `App.js`)
- [ ] `lune doctor` — check crystal/node versions, shard resolvable, frontend builds
- [ ] Single-instance lock — lock file or UNIX socket at `~/.lune/<app>.lock`
- [ ] Window state persistence — save/restore position+size to `~/.config/<app>/window.json`

## v0.3 — Production-ready

- [ ] Dev error overlay — pipe Crystal compile errors into the webview as an HTML overlay when `lune dev` compilation fails
- [ ] Structured binding errors — define an error envelope with a `code` field so JS can branch on `e.code` instead of parsing the message string
- [ ] GitHub Actions release pipeline — build macOS + Linux binaries on tag push, attach to GitHub release
- [ ] `lune generate` — codegen binding registration boilerplate and `.d.ts` from Crystal annotations

## Needs C bindings — post-v0.3

These require native platform APIs beyond what `webview.h` exposes.

- [ ] Native file dialogs (NSOpenPanel / GetOpenFileName / GTK)
- [ ] System tray
- [ ] Native menus
- [ ] OS notifications
- [ ] Multiple windows
- [ ] Screen info / DPI queries
