# Windows verification checklist

Real-hardware testing of Lune on Windows is in progress. As of v0.11.0
the toolchain compiles (with the Crystal 1.20.2 `Process.initialize`
patch documented in `WINDOWS_SETUP.md`) and the demo runs end-to-end
via `lune dev --debug`.

This page tracks which capabilities have been exercised on real
Windows hardware and what's known to be broken. Items marked
**verified** have been run interactively; items marked **broken** or
**not implemented** have known gaps tracked in `ROADMAP.md`.

## Verified working

- **Smoke**: `lune dev` boots, the window opens, navigates to the Vite
  dev URL, no crash or hang.
- **System**:
  - `System.environment()` returns `{ os: "windows", arch: "x86_64" }`
  - `System.openUrl(...)` opens the default browser
  - `System.quit()` closes the window cleanly
- **Stream**: WebSocket bidirectional IPC works (bind + listen on the
  same execution context so IOCP completions route correctly — see
  `src/lune/capabilities/stream.cr` win32 branch).
- **Events**: `app.events.emit` / `Events.on` round-trip works.
- **Clipboard** (plaintext + HTML):
  - `Clipboard.read()` / `Clipboard.write(text)` are instant — they go
    through Win32 `CF_UNICODETEXT` directly (no PowerShell shellout).
  - `Clipboard.readHtml()` / `writeHtml(html)` work via the existing
    `CF_HTML` clipboard format.
- **Hotkeys**: `Hotkeys.register` / `unregister` work and the combo
  actually fires on press. `WM_HOTKEY` is delivered via a dedicated
  pump thread; the `Msg.w_param` field is declared as `UInt64` so it
  aligns on the right offset under Windows LLP64 (an earlier
  `LibC::ULong` declaration silently read from padding, so registration
  succeeded but the ID lookup always returned nil — fixed in v0.11.1).
  `unregister_all` on shutdown is fire-and-forget (Channel-receive
  across Isolated contexts isn't safe). Per-binding async dispatch
  means the pump thread is reachable from binding callbacks without a
  deadlock.
- **Window state**: opt-in via `opts.remember_frame = true`. The
  Windows path uses a live tracker (`WindowState.start_tracker`) that
  polls `GetWindowRect` every 500 ms — the HWND is destroyed by the
  time `wv.run` returns, so the usual on-close save would persist
  zeros.
- **Sqlite** / **Kv**: confirmed working. Sqlite goes through the
  bundled `sqlite3.dll` (`WINDOWS_SETUP.md` step 4 builds the import
  library); Kv is pure Crystal on top of the filesystem.
- **Shell**:
  - Real executables work (`Shell.run("git", ["status"])`, etc.).
  - Async-marked bindings (`Shell.spawn`, `Shell.run`) route through
    the @async_pool so `Process.run`'s internal copy_io / wait fibers
    don't trip the Isolated-context concurrency check.

## Broken / partial

- **Multi-window OS close propagation** (`Windows.open(...)`) — closing a child window via the title-bar X doesn't notify the Crystal side. The `@windows` registry still thinks the window is open and any code waiting for a close event hangs. macOS solved this via `NSWindowDelegate#windowWillClose:`; Win32 needs a WindowProc subclass on the child HWND that intercepts `WM_CLOSE`/`WM_DESTROY`. Tracked in `ROADMAP.md`.
- **DeepLink on Windows** — `install` doesn't crash and cold-start ARGV scanning works, but only if the user has manually registered the URL scheme in the Windows registry. Lune doesn't auto-register schemes during `lune build` yet. Warm-start forwarding (sending a URL to an already-running instance) also isn't implemented on Windows — each launch with a deep-link URL opens a new instance. Tracked in `ROADMAP.md`.
- **Notifications** (`Notifications.notify`) — the PowerShell + WinRT
  script now exits cleanly (both `Windows.UI.Notifications` and
  `Windows.Data.Xml.Dom` projections are explicitly loaded) but
  Windows **silently drops the toast** because the AUMID `"Lune"`
  isn't registered with the OS. Distributed apps need a Start Menu
  shortcut with `System.AppUserModel.ID` set. Tracked under "Windows
  toast notifications" in `ROADMAP.md`.
- **Drag-and-drop** (`file_drop` capability) — currently raises
  `NotImplementedError` (`Native::Window.disable_webview_drop` and the
  underlying drop-target plumbing are macOS-only). Exclude `file_drop`
  in `lune.yml` until the Win32 `IDropTarget` shim lands. The demo's
  drop zone won't fire any callbacks.
- **Shell builtins** — `Shell.spawn("echo …")`, `dir`, `type`, etc.
  fail with `File::NotFoundError` because those are cmd builtins, not
  real `.exe`s. Wrap them as `cmd /c <builtin> …` or use a real
  binary. Tracked in `ROADMAP.md`.
- **Privileged commands** — anything that needs Administrator (e.g.
  `ping -t …`, low-level network probes) errors with "Access denied"
  or "requires administrative privileges". Run the parent shell as
  admin if you need these, or use a non-privileged equivalent. Not a
  Lune bug.

## Not implemented (raise `NotImplementedError`)

Each of these needs to be added to your app's `lune.yml`
`capabilities.exclude` list on Windows until the implementation lands.
All are tracked under v0.12.0 in `ROADMAP.md`:

- `tray` — needs hidden HWND + `Shell_NotifyIconW`
- `file_watch` — needs `ReadDirectoryChangesW`
- `file_drop` — needs `IDropTarget`/`OleInitialize` + drop callback
- `drag_out` — macOS-only by design
- `context_menu` — the Win32 `TrackPopupMenu` shim is in tree and the capability layer calls into it, but WebView2's built-in browser context menu shows on top and JS `preventDefault()` doesn't suppress it. Needs `ICoreWebView2_*` access to set `AreDefaultContextMenusEnabled = false` (or handle `ContextMenuRequested`). Exclude `context_menu` on Windows until that's wired up.
- `Clipboard.readImage` / `writeImage` — needs PNG ↔ CF_DIB conversion
- `Menu.setupDefault` / `setFromOptions` — window menu bar not yet
  ported; needs `SetMenu` + `CreatePopupMenu` + `AppendMenuW` +
  WM_COMMAND dispatch (and `TranslateAccelerator` for shortcuts)

## Dialogs — verified

- [x] `Dialogs.openFile()` shows the Windows file picker; cancel
      returns `""`
- [x] `Dialogs.openDir()` shows the Browse-Folder picker
- [x] `Dialogs.openFiles()` allows multi-select
- [x] `Dialogs.saveFile()` warns on overwrite, returns chosen path
- [x] `Dialogs.message_info` / `message_warning` / `message_error` /
      `message_question` now use the correct icon + buttons. (The
      Win32 native code previously had a type-code mismatch — warning
      showed Yes/No, error showed OK/Cancel, question showed only OK.
      Fixed in v0.11.0; verify after rebuild.)

## Reporting

If anything in this checklist's **Verified working** section regresses
or any new failure mode appears, open an issue with:

- Windows version (`winver`)
- The exact JS call you made
- Output of `lune dev --debug` covering the failure
- Crystal version (`crystal -v`)
