# Lune Roadmap Ideas

## Up next — no C bindings required

- [ ] Window controls at runtime from JS — `minimize()`, `maximize()`, `setTitle()`, `setSize()`, `center()` as runtime bindings via `wv.dispatch` + native handles
- [x] Clipboard bridge — `readText()` / `writeText()` from JS via platform commands (`pbpaste`/`pbcopy`, `xclip`, `clip`)
- [x] App paths bridge — `appDataDir()`, `homeDir()`, `downloadsDir()` etc. from JS via Crystal `Path.home` and platform conventions
- [x] `lune.yml` window defaults — declare `title`, `width`, `height`, `resizable` in config so apps don't repeat them in the opts block
- [ ] Capability allowlist — opt-in per-app to which runtime bindings are exposed to JS (security; modelled after Tauri capabilities)
- [ ] App icon support — bundle platform icon assets (`.icns` on macOS, `.ico` on Windows, `.png` on Linux) into the `lune build` output

## v0.2

- [x] Events system: `app.emit("event", data)` from Crystal → JS event bus (`on`/`once`/`off` in runtime.js)
- [x] Runtime JS API — `quit()`, `openURL(url)`, `environment()` built into `runtime.js`
- [x] TypeScript definitions — `runtime.d.ts` (fully typed) and `App.d.ts` (name stubs) generated alongside JS files
- [x] `lune doctor` — check crystal/node versions, shards installed, frontend deps
- [x] Single-instance lock — lock file or UNIX socket at `~/.lune/<app>.lock`
- [x] `lune.yml` project config — set `dev_cmd`, `build_cmd`, `dev_url`, `app_entry`, and `frontend_dir` per project; scaffolded by `lune init`
- [x] GitHub Actions release pipeline — build macOS + Linux binaries on tag push, attach to GitHub release

## v0.3

- [x] codegen binding registration boilerplate and `.d.ts` from Crystal annotations
- [x] Dev error overlay — when `lune dev` compilation fails, the CLI spawns a dedicated error window showing the Crystal compiler output; closes on next successful build
- [x] Structured binding errors — define an error envelope with a `code` field so JS can branch on `e.code` instead of parsing the message string
- [ ] Additional templates: Svelte, React+TS

## Needs C bindings — post-v0.3

These require native platform APIs beyond what `webview.h` exposes.

- [ ] Native file dialogs (NSOpenPanel / GetOpenFileName / GTK)
- [ ] System tray
- [ ] Native menus
- [ ] OS notifications
- [ ] Multiple windows
- [ ] Screen info / DPI queries

## Random — no timeline

- [ ] Window state persistence — save/restore position+size to `~/.config/<app>/window.json`
