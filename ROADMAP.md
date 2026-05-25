# Lune Roadmap

Open work, organized by category. Shipped items live in the [CHANGELOG](CHANGELOG.md).

## Native capabilities

Things the OS exposes that Lune doesn't yet surface.

- [ ] **`autostart` plugin** — register the app to launch at login (LaunchAgent on macOS, `.desktop` `Autostart` entry on Linux, `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` on Win32).
- [ ] **Reactive SQLite** — `Sqlite.watch(db, sql, params, cb)` re-runs a query and pushes updated rows whenever the database is written; pairs with `Stream` for live Vue reactivity.

## Cross-platform parity

Plugins or behaviours that work on some OSes but not others.

- [ ] **Linux / Windows `drag_out`** — currently darwin-only (declared via `Descriptor#platforms`). On Linux/Windows the runtime exports a rejecting stub so user code can `.catch` cleanly. Real implementation needs X11 XDND on Linux and `OleInitialize` + `DoDragDrop` with an `IDataObject` carrying `CFSTR_FILEDESCRIPTORW` on Win32. Both need native window subclassing and pasteboard plumbing we don't have today.
- [ ] **Linux window drag** — `opts.window.drag_zone` works on macOS (`NSWindow performWindowDrag`) and Windows (`ReleaseCapture()` + `SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0)`). Linux still needs X11 `XSendEvent` with `_NET_WM_MOVERESIZE` (and Wayland `xdg_toplevel.move()` via `wl_seat`).
- [ ] **Windows `file_drop`** — currently raises `NotImplementedError`. Both the webview-drop suppression (`Native::Window.disable_webview_drop`) and the actual drop-callback wiring are macOS-only. Needs `OleInitialize` + `RegisterDragDrop` with a custom `IDropTarget` implementation that calls into Crystal via a boxed callback, plus a `disable_webview_drop` equivalent that stops WebView2's built-in drop handler from intercepting. Until then exclude `file_drop` in `lune.yml` on Windows.
- [ ] **Linux `menubar_mode`** — macOS uses `NSApplicationActivationPolicyAccessory` + `NSWindowDidResignKeyNotification`; Win32 uses `WS_EX_TOOLWINDOW` + `WM_ACTIVATEAPP`. Linux silently ignores `opts.menubar_mode`; the likely close-out is GTK `_NET_WM_STATE_SKIP_TASKBAR` + `_NET_WM_STATE_SKIP_PAGER` + a `FocusOut` observer.

## Architecture

Structural improvements that unlock whole categories of apps.

- [ ] **Plugin-scoped event/stream namespacing** — today a plugin author writes `@app.event.emit("counter:changed", …)` and is responsible for prefixing the event name with the plugin's id to avoid collisions. Auto-namespace the bus when accessed from inside a plugin: `@app.event.emit("changed", …)` from a plugin with `descriptor.id == :counter` would dispatch under `counter:changed`, and the JS-side listener `lune.Event.on("counter:changed", …)` stays unchanged. Same for `@app.stream.send`. Likely shape: a plugin-bound facade (`@event` / `@stream`) that wraps the global bus and stamps the prefix on `emit` / `send` / `on` / `off`. Open questions: should listening to _other_ plugins' events stay on the raw `@app.event` accessor (explicit cross-plugin), or auto-prefix with a parameter (`@event.on(:other_plugin, "changed", …)`)? And what's the separator — `:`, `.`, `/` — given the JS side uses arbitrary strings today?
- [ ] **Per-window plugins** — scope `enabled` / `disabled` lists to individual windows rather than globally.
- [ ] **Window-aware option callbacks** — `opts.on_navigate` (and likely `on_load` / `on_close`) gets only the URL today; in multi-window apps it can't tell which window fired. Extend the proc signature with a window id, or pass an event struct. Likely shares design with per-window plugins.
- [ ] **Multiple webviews in one window** — stack or embed multiple WebView panels within a single native window.
- [ ] **`ext/native/windows/` shim parity** — Win32 currently calls `user32` / `shell32` / `comdlg32` / etc. directly from `src/lune/native/*.cr` via `@[Link("…")]`, while macOS and Linux use `.m` / `.c` shims compiled into `ext/native/<platform>/*.o` linked behind a uniform `LibNativeFoo`. Direct FFI works (Tauri/Rust do the same on Win32) but the inconsistent pattern complicates per-plugin branching. Refactor to add `ext/native/windows/*.cpp` shims compiled via `cl.exe` so every platform exposes the same `LibNativeFoo` interface.

## Shipping & DX

- [ ] **Auto-updater** — in-app update checks and installs driven by a manifest URL; Sparkle on macOS, equivalent on Linux / Windows.
- [ ] **Windows release artifact** — `release.yml` matrix is Linux + macOS arm64 only. Adding `windows-latest` needs the Windows prep `specs.yml` already has (MSVC, `LibC::PidT` stdlib patch, WebView2 SDK headers, sqlite3.lib + webview.lib builds, LIB / PATH / CPATH env wiring) plus a real `shards build --release` — specs only `--no-codegen` type-check the Win32 paths today, so the first real link may surface errors. Product decision: ship `lune.exe` bare and document the `webview.dll` / `sqlite3.dll` runtime prerequisites, or zip the artifact with sidecar DLLs.
- [ ] **Splash screen** — show a configurable loading view while the Crystal runtime and frontend initialise.
- [ ] **Additional templates** — Svelte, React + TypeScript.

## Blocked on upstream

Items the project can't pursue until external dependencies move. Each entry names the dependency.

- [ ] **Win32 runtime end-to-end build — Crystal ≥ 1.21.** v0.10.0 + v0.11.0 added Win32 implementations for window / screen / dialog / clipboard-html / hotkeys / context-menu / notify / deep-link-cold-start, but Crystal 1.20.x can't compile a runnable binary on MSVC (`LibC::PidT` missing in `Process.initialize`; fixed in [crystal#16933](https://github.com/crystal-lang/crystal/pull/16933)). Once 1.21 is in our toolchain, walk through the **Platform notes** on each [plugin page](website/plugins/) and verify each plugin end-to-end on Windows.
- [ ] **Win32 menu-accelerator routing — `webview/webview` shard.** The menu bar itself ships (`Lune::Native::Menu.set_from_options` builds an HMENU tree via `CreateMenu` / `CreatePopupMenu` / `AppendMenuW`, attaches it via `SetMenu`, and `WindowProc` subclassing routes `WM_COMMAND` to Crystal callbacks). Submenus, separators, checkboxes, radios, and nested menus all click through. Accelerator strings render as right-aligned hint text in the menu (`"cmd+p"` → `Ctrl+P`) but the key combo doesn't actually fire the action. **This matches Wails' Windows behaviour exactly** ([wails winc/menu.go](https://github.com/wailsapp/wails/blob/master/v2/internal/frontend/desktop/windows/winc/menu.go) — shortcut text is `fmt.Sprintf("%s\t%s", …)` cosmetic only). The proper fix needs `CreateAcceleratorTableW` + `TranslateAcceleratorW(hwnd, haccel, &msg)` called between `GetMessage` and `DispatchMessage` (Tauri's path via [muda](https://github.com/tauri-apps/muda) + [tao](https://github.com/tauri-apps/tao)'s `with_msg_hook`). The C `webview/webview` shard we use hides `run_loop()` and doesn't expose `ICoreWebView2Controller*`, so neither the pump-hook path nor `add_AcceleratorKeyPressed` is reachable from our side. Real fix: patch the shard upstream to expose either the pump or the controller, then wire `TranslateAcceleratorW` (preferred — also routes WV2's swallowed defaults like Ctrl+P).
- [ ] **Win32 WebView2 default-accelerator suppression — `webview/webview` shard.** WebView2's `ICoreWebView2Settings.AreBrowserAcceleratorKeysEnabled` defaults to `true`, so Ctrl+P / Ctrl+F / Ctrl+R / Ctrl+- / etc. trigger Edge-style browser behaviour even when the app doesn't want it. Needs the webview shard to expose the setting so Lune can default it to `false` (or let apps choose). Complements the Win32 menu-accelerator item — together they fully fix the keyboard-shortcut routing story on Win32.
- [ ] **Win32 `context_menu` default suppression — `webview/webview` shard.** The native `TrackPopupMenu` shim is in tree (`Lune::Native::Menu.show_context_menu`) and the plugin layer wires it up. But WebView2 still shows its own built-in browser context menu, which obscures (or overrides) our native one. JS `e.preventDefault()` on the DOM `contextmenu` event doesn't stop WebView2 because the browser menu is driven by `ContextMenuRequested` at the WV2 controller level. Needs the webview shard to expose either `AreDefaultContextMenusEnabled = false` on `ICoreWebView2Settings` or a hook on `ContextMenuRequested` so we can flag `Handled = true`. Until that lands, `context_menu` should stay excluded on Windows.

---

_For the full shipped feature list, see [CHANGELOG.md](CHANGELOG.md)._
