# Lune Roadmap Ideas

## v0.2 — Developer experience

- [x] Events system: `app.emit("event", data)` from Crystal → JS event bus (`on`/`once`/`off` in runtime.js)
- [x] Runtime JS API — `quit()`, `openURL(url)`, `environment()` built into `runtime.js`
- [x] TypeScript definitions — `runtime.d.ts` (fully typed) and `App.d.ts` (name stubs) generated alongside JS files
- [x] `lune doctor` — check crystal/node versions, shards installed, frontend deps
- [x] Single-instance lock — lock file or UNIX socket at `~/.lune/<app>.lock`
- [x] `lune.yml` project config — set `dev_cmd`, `build_cmd`, `dev_url`, `app_entry`, and `frontend_dir` per project; scaffolded by `lune init`

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

## Random — no timeline

- [ ] Additional templates: Svelte, React+TS (wait until core API is stable)
- [ ] Window state persistence — save/restore position+size to `~/.config/<app>/window.json`
