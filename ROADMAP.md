# Lune Roadmap

## Production-ready/Windows support

The gaps that prevent Lune apps from shipping as standalone products.

- [ ] Auto-updater — in-app update checks and installs driven by a manifest URL; Sparkle on macOS, equivalent on Linux/Windows
- [ ] Windows runtime — blocked on **Crystal 1.21.0**. v0.10.0 + v0.11.0 added Win32 implementations for window/screen/dialog/clipboard-html/hotkeys/context-menu/notify/deep-link-cold-start, but Crystal 1.20.x can't compile a runnable binary on MSVC (`LibC::PidT` missing in `Process.initialize`; fixed in [crystal#16933](https://github.com/crystal-lang/crystal/pull/16933), shipping in 1.21). Once 1.21 lands, walk through [`website/guide/windows-checklist.md`](website/guide/windows-checklist.md) to verify each capability.
- [x] Windows toast notifications — `Notifications.notify` now registers the AUMID via `HKCU\Software\Classes\AppUserModelId\<aumid>` on first use (Microsoft's documented path for non-UWP desktop apps). Toasts display correctly. AUMID is hardcoded to `"Lune"`; per-app AUMID derived from `lune.yml`'s `name:` is a follow-up.
- [ ] Windows menu support — `Native::Menu.set_from_options` and `setup_default` are macOS-only. Windows apps currently launch without any window menu. Needs Win32 `CreateMenu` + `CreatePopupMenu` + `AppendMenuW` + WM_COMMAND dispatch (with WindowProc subclassing to route the command IDs back to Crystal callbacks). Should also handle accelerator keys via `TranslateAccelerator`. **Visible symptom**: app-declared menu accelerators (e.g. the demo's `cmd+p` Pause-Clock shortcut) fall through to WebView2's built-in browser shortcuts on Windows — Ctrl+P opens WebView2's Print dialog because nothing intercepts the key at the OS level first. Implementing accelerator table + `TranslateAccelerator` in the message-pump fixes this since it runs before WebView2's keyboard handler.
- [ ] Windows WebView2 default-accelerator suppression — WebView2's `ICoreWebView2Settings.AreBrowserAcceleratorKeysEnabled` defaults to `true`, so Ctrl+P / Ctrl+F / Ctrl+R / Ctrl+- / etc. trigger Edge-style browser behavior even when the app doesn't want it. Needs the webview shard to expose the setting so Lune can default it to `false` (or let apps choose). Complements the Windows menu support item — together they fully fix the keyboard-shortcut routing story on Win32.
- [x] Windows Shell builtins — `Shell.spawn` / `Shell.run` now catch `File::NotFoundError` and retry via `cmd /c`, transparently covering cmd builtins (`echo`, `dir`, `type`, `cd`, `more`, …) and `.cmd` / `.bat` shims.
- [ ] Linux/Windows `drag_out` — the capability is currently darwin-only (declared via `Descriptor#platforms`). On Linux/Windows the runtime exports a rejecting stub so user code can `.catch` cleanly, but a real implementation needs X11 XDND on Linux and `OleInitialize` + `DoDragDrop` with an `IDataObject` carrying `CFSTR_FILEDESCRIPTORW` on Win32. Both need native window subclassing and pasteboard plumbing we don't have today.
- [ ] Windows drag-and-drop (`file_drop`) — currently raises `NotImplementedError`. Both the webview-drop suppression (`Native::Window.disable_webview_drop`) and the actual drop callback wiring are macOS-only. Needs `OleInitialize` + `RegisterDragDrop` with a custom `IDropTarget` implementation that calls into Crystal via a boxed callback. Should also include `disable_webview_drop` equivalent (stop WebView2's built-in drop handler from intercepting). Until then exclude `file_drop` in `lune.yml` on Windows.
- [ ] Windows secondary-window OS close propagation — closing a `Windows.open(...)` child window via the OS title-bar X doesn't notify Lune. The Crystal-side `@windows` registry still thinks the window is open, no shutdown hook fires, and any code waiting for the close event hangs. macOS solved this by subclassing `NSWindowDelegate#windowWillClose:`; Win32 needs the equivalent — a WindowProc subclass on the child HWND that intercepts `WM_CLOSE`/`WM_DESTROY` and posts a "window closed" event into the Crystal runtime before the OS finishes tear-down.
- [ ] Windows `context_menu` suppression of the default WebView2 browser menu — the native `TrackPopupMenu` shim is in tree (`Lune::Native::Menu.show_context_menu`) and the capability layer wires it up. But WebView2 still shows its own built-in browser context menu, which obscures (or overrides) our native one. JS `e.preventDefault()` on the DOM `contextmenu` event doesn't stop WebView2 because the browser menu is driven by `ContextMenuRequested` at the WV2 controller level. Needs the webview shard to expose either `AreDefaultContextMenusEnabled = false` on `ICoreWebView2Settings` or a hook on `ContextMenuRequested` so we can flag `Handled = true`. Until that lands, `context_menu` should stay excluded on Windows.
- [x] App icon support on Windows — `.ico` embedded into `lune build` via generated `.rc` + `rc.exe` (v0.11.0).

## Native APIs

Features the platform exposes that Lune doesn't yet surface.

- [ ] `autostart` capability — register the app to launch at login (LaunchAgent on macOS, `.desktop` on Linux)
- [ ] Reactive SQLite — `Sqlite.watch(db, sql, params, cb)` re-runs a query and pushes updated rows whenever the database is written; pairs with Stream for live Vue reactivity
- [ ] Dialogs file-type filters — `Dialogs.openFile` / `openFiles` / `saveFile` currently take only a prompt string; the underlying native APIs all support filter hints (`lpstrFilter` on Win32 `GetOpenFileNameW`, `allowedContentTypes`/`allowedFileTypes` on macOS `NSOpenPanel`, `GtkFileFilter.add_pattern` on Linux). Plumb a `filters: [{name, extensions}]` parameter through the capability + native shims so picker dialogs can constrain to e.g. `.ico` only. Discovered while building the tray demo's icon picker — currently users see all files and have to know `.ico` is the only supported format on Win32.
- [ ] Windows `opts.tray.toggle_window_on` — currently a no-op on Win32 (`Lune::Capabilities::Tray.build_window_toggle` wraps its body in `{% if flag?(:darwin) %}` because positioning the window relative to the tray icon needs `Lune::Native::Tray.button_screen_rect`, which is macOS-only). Implementing on Windows means using `Shell_NotifyIcon(NIM_SETVERSION, NOTIFYICON_VERSION_4)` + `Shell_NotifyIconGetRect` (Win7+) to get the icon's screen rect, then positioning the window above the system tray (bottom-right on most Windows layouts). Same pattern would also enable a Windows menubar-mode story analogous to `mac.menubar_mode`. Until then, popover-style Lune apps work on macOS only; Windows users have to wire their own `opts.tray.on_click` if they want click-to-toggle behaviour.

## Architecture

Structural improvements that unlock whole categories of apps.

- [ ] Plugin system — a Crystal shard interface (`Lune::Plugin`) with lifecycle hooks and runtime binding registration so community authors can publish Lune plugins
- [ ] Per-window capabilities — scope `enabled`/`disabled` lists to individual windows rather than globally
- [ ] Multiple webviews in one window — stack or embed multiple WebView panels within a single native window
- [ ] `ext/native/windows/` shim parity — Win32 currently calls `user32`/`shell32`/`comdlg32`/etc. directly from `src/lune/native/*.cr` via `@[Link("…")]`, while macOS and Linux use `.m`/`.c` shims compiled into `ext/native/<platform>/*.o` linked behind a uniform `LibNativeFoo`. Direct FFI works (Tauri/Rust do the same on Win32) but the inconsistent pattern complicates per-capability branching. Refactor to add `ext/native/windows/*.cpp` shims compiled via `cl.exe` so every platform exposes the same `LibNativeFoo` interface.

## DX & Templates

- [ ] Splash screen — show a configurable loading view while the Crystal runtime and frontend initialise
- [ ] Additional templates — Svelte, React + TypeScript

---

_For the full shipped feature list, see [CHANGELOG.md](CHANGELOG.md)._
