# Changelog

## [0.14.0] - 2026-05-23

### Added

- **`Lune::APP_NAME`** — display name baked into the binary at compile time from `lune.yml`'s `name:` (CLI sets `LUNE_APP_NAME`). Defaults to the app entry's basename, or `"Lune"` when built outside the CLI.

### Fixed

- **Win32 window drag** — `opts.window.drag_zone` now drives a native drag on Windows. Previously a no-op outside macOS.
- **Win32 tray `toggle_window_on`** — left- / right-click now toggles the main window, positioned above the taskbar icon. Previously a no-op outside macOS.
- **Win32 `Window.hide` / `show` / `visible?`** — actually drive the window's visibility (were silent no-ops).
- **Win32 toast AUMID** — derived from `lune.yml`'s `name:` so each app gets its own registry subkey and `DisplayName`. Previously hardcoded to `"Lune"`.
- **Win32 `file_watch`** — backed by `ReadDirectoryChangesW` + IOCP; emits the same `modified` / `created` / `deleted` / `renamed` events as macOS and Linux. Plugin descriptor flipped from `[:darwin, :linux]` to all three.
- **`edit_shortcuts` no longer breaks Ctrl/Cmd+V in inputs** — the `keydown` interceptor now skips `INPUT` / `TEXTAREA` / `contenteditable` targets and defers to the browser's native handler. `document.execCommand('paste')` is blocked in WebView2/Chromium, so the previous intercept turned paste into a silent no-op inside text fields.
- **Win32 `Clipboard.readImage` / `writeImage`** — PNG ↔ `CF_DIB` via a PowerShell + `System.Drawing.Bitmap` shellout. Bindings flipped to `async: true` so the call doesn't block the webview's Isolated fiber.

## [0.13.0] - 2026-05-23

### Breaking

- **`Events` plugin renamed to `Event`** to match the singular `Stream`. Search-and-replace in user code; no shim.
- **`Capability` → `Plugin`** throughout the public API. `lune.yml` `capabilities:` is now `plugins:` (old key parsed with a deprecation warning for one minor).
- **Bridge binding IDs unified.** User class `Demo.greet` and plugin `Tray.show` produce the same shape (no `__lune.` prefix on plugin IDs). Three hand-bound framework bindings — `jsEmit`, `startDrag`, `navigate` — are now regular `@[Lune::Bind]` methods.
- **Binding namespaces follow the Crystal module path 1-to-1.** `Lune::Plugins::Tray.show` produces `Lune.Plugins.Tray.show` (was `Tray.show`). `runtime.js` exports one `Lune` object plus `lune = Lune.Plugins`; per-plugin top-level exports are gone.
- **`include` / `exclude` → `enabled` / `disabled`** in `lune.yml` `plugins:` blocks and on `ConfigPlugins`. Identical semantics.
- **Plugin config moves into each plugin class** via a `config do … end` macro: `Lune::Options::Tray` → `Lune::Plugins::Tray::Config`, etc. `opts.tray { … }` and `opts.tray.event = …` still work.
- **`ContextMenuBlocker` merged into `ContextMenu`** — set `opts.context_menu.block_default = true`. `opts.disable_context_menu` shortcut removed.
- **`opts.window_drag.value` removed.** Drag activation matches any non-empty CSS value on the configured property — `style="--lune-draggable: true"` reads as a boolean flag.
- **`WindowDrag` merged into `Window`** — `opts.window.drag_zone = "--lune-draggable"` (was `opts.window_drag.zone`). JS binding is now `Lune.Plugins.Window.start_drag`.
- **`Screen` merged into `System`** — `lune.System.screenInfo()` / `System#screen_info` replace `lune.Screen.info()` / `Screen#info`.
- **`Notifications` merged into `System`** — `lune.System.notify(title, body)` replaces `lune.Notifications.notify(title, body)`.
- **Menu shortcut parsing moved into the native shims** (ObjC on macOS, equivalent on Win32 — matches `Native::Hotkeys`). `Options::Menu#to_json` emits the raw `shortcut: "cmd+n"` string; the user-facing API is unchanged. `ext/native/macos/` → `ext/native/darwin/`.
- **Hand-written TS interfaces dropped from `runtime.d.ts`** (`LuneEnvironment`, `ScreenInfo`, `TrayMenuItem`, `ContextMenuItem`) — every binding signature now derives from the plugin source. Migration: alias the inferred return type, or annotate the return struct with `@[Lune::TsType]` (see Changed). Only `LuneError` stays in the header.

### Added

- **`Lune.use(*plugins)` — public registration entry point.** Variadic, shape matches `App#install(*mods)`. Third-party shards publish a `class MyPlugin < Lune::Plugin` and the consuming app calls `Lune.use(MyPlugin.new)` (or `Lune.use(A.new, B.new, C.new)`) before `Lune.run`. Built-ins go through the same path: `src/lune/plugins/builtins.cr` calls `Lune.use(Event.new, Stream.new, …)` at require time, so by the time `Lune.run` fires the registry holds first-party and third-party plugins side by side. `Lune.registered_plugins` exposes the list; `Lune.with_plugins(*ps) { … }` is a spec helper that snapshots / replaces / restores the registry around a block. `Plugins::Registry#initialize` consumes `Lune.registered_plugins` instead of a hardcoded array. Three guards run at `use` time, each raising `Lune::RegistrationError` (a typed `Lune::Error` subclass) with an actionable hint: (1) duplicate `descriptor.id`; (2) duplicate `opts.<name>` accessor (two plugins claiming the same accessor would otherwise silently fight at compile time — Crystal lets the second `def` win on the reopened `Lune::Options`); (3) class names under the reserved `Lune::Plugins::` namespace that aren't on the blessed-built-ins list. The `config` macro accepts an explicit accessor as a positional override (`config(:my_unique_name) do …`) so a third-party plugin whose class basename happens to underscore to a built-in's accessor can opt out of the collision.
- **Centralized error types — `Lune::RegistrationError`, `Lune::ConfigurationError`, `Lune::BridgeNotReadyError`** all under a single `Lune::Error` root. Every framework-raised exception now carries a stable `code` (read by `Bridge` to forward typed errors to JS) and an optional `hint`. `Lune::Error#inspect_with_backtrace` is overridden so unhandled framework errors print as `[CODE] message` followed by `Fix: <hint>` — no Crystal stack trace, no `(ArgumentError)` suffix that read like an internal crash. Set `LUNE_TRACE=1` to restore the default Crystal output for debugging. Replaces three bare `ArgumentError` raises in `Lune.use`, a `raise "..."` (untyped `RuntimeError`) in `Runner` for missing navigation source, and a `raise "..."` in the `config` macro for `opts.<plugin>` referenced before `Lune.use`. `Lune::BridgeNotReadyError` rebased from `Exception` onto `Lune::Error` so the JS bridge sees a code (`BRIDGE_NOT_READY`) instead of the generic `"error"` fallback.
- **`Plugin::SetupCtx#on_quit`** lets plugins receive the runtime quit callback through the same context object that already carried `options` and `handle`, replacing the bespoke `Plugins::System.new(on_quit)` constructor argument. Every built-in is now default-constructible (`Plugins::System.new`, `Plugins::Tray.new`, …) which is the precondition for `Lune.use(X.new)` and for the Phase 4 config DSL.
- **`lune doctor` lists registered plugins** with platform availability and soft-dep gaps after the environment checks. ✓ for active, ✗ for platform-filtered, and a `soft dep <id> not active` annotation when a dependent's optional dep isn't in the active set. Add `--plugins` to also see project-side `Lune.use` calls: the flag compiles + runs the app entry with a new `-Dlune_inspect` build flag, which short-circuits `Lune.run` after the registry is populated and prints the registered set in a framed format the doctor parses (WYSIWYG — same shape the live app would see, no regex scan).
- **`lune init` template** mentions third-party plugin registration. The scaffolded `main.cr` includes a commented `require "my_plugin"` / `Lune.use(MyPlugin::Plugin.new)` block so new app authors see where external plugins plug in.
- **[Authoring Plugins guide](https://lune-app.dev/guide/authoring-plugins)** — third-party shard layout, descriptor fields, the `config do` macro, lifecycle phases, JS namespace rules, `init_js` re-entry contract, platform gating, cross-plugin lookup, testing via `Lune.with_plugins`, and a publishing checklist. `website/guide/bindings.md` gains a short "user bindings vs plugin bindings" section linking to it.
- **Two runtime behaviors are now disable-able via `lune.yml`** — `edit_shortcuts` (cmd/ctrl+A/C/V/X/Z/Y → execCommand) and `navigation` (drives `opts.on_navigate`). Previously injected unconditionally from the runner; now first-class plugins you can opt out of via `plugins.disabled`. (Window drag was the third behaviour graduated here, but a later entry above folds it back into the `Window` plugin — it's now an opt-in via `opts.window.drag_zone`, not a separate registry entry.)

### Changed

- **Crystal → TypeScript type mapping auto-derives generics, NamedTuples, and enums.** Recursive coverage for `Array(T)`, `Hash(K, V)`, `Tuple(...)`, `NamedTuple(field: T, …)`, and Crystal `enum` returns (string union matching `Enum#to_json`'s snake_case output). New `@[Lune::TsType]` annotation on a struct / record / class makes the generator emit one `export interface <Name> { ... }` and reference it by name from the binding signature — replaces `Promise<Record<string, any>>` for plugin-defined return types. `@[Lune::BindOverride(ts_return_type:)]` still wins over both auto-paths and remains the escape hatch for inlined literal unions (`String` → `"darwin" | "linux" | "windows"`). Limits: TsType is return-position only; simple class name only (basenames must be unique); no cycle detection. Reference consumer: `MyCustomPlugin::CounterState` in `demo/src/counter.cr`, imported into `Counter.vue` by name.

### Fixed

- **`App#eval` raises a typed `Lune::BridgeNotReadyError`** instead of a generic `NilAssertionError` when called before the runner wires the bridge (e.g. from a plugin `install` hook or an `App#async` task that races startup). **`App#close!` now returns early** when the bridge has not been wired yet — useful when a SIGINT during init triggers the shutdown path before bridge attach.
- **Win32 Shell builtins** — `Shell.spawn` / `Shell.run` fall back to `cmd /c` on `File::NotFoundError`, so `echo`, `dir`, `npm.cmd`, etc. work directly. Helper: `Lune::Plugins::Shell.with_win32_cmd_fallback`.
- **Win32 toast notifications** — `System.notify` registers the AUMID at `HKCU\Software\Classes\AppUserModelId\Lune` on first call; toasts actually display instead of being silently dropped.
- **Win32 `lune build` blank window** — `Assets::Server` now binds + listens from the same `::spawn` on the default context (mirroring Stream's Win32 pattern) so IOCP accept completions reach the listen fiber. POSIX path unchanged.
- **Win32 secondary-window close** — `Native::Window.close` posts `WM_CLOSE` via `PostMessageW`, and `Native::Window.on_close` subclasses the child HWND via `SetWindowLongPtrW(GWLP_WNDPROC, …)` to trap `WM_DESTROY` and run the cleanup block before forwarding to the previous WNDPROC. `Windows.close(id)` actually closes the window, and the user clicking the X now fires `window_closed` to the main window.
- **`opts.on_navigate` fires on SPA routing** — `history.pushState` / `replaceState` are shimmed so React Router, Vue Router (HTML5 mode), Next client transitions, etc. trigger the callback. Same-URL fires are deduped so vue-router hash mode (which calls both pushState and mutates `location.hash`) doesn't double-fire.
- **`Lune::App` / `Lune::Bridge` no longer eagerly allocate thread pools** — the `Fiber::ExecutionContext::Parallel` (kqueue + `cpu_count` workers) is lazy-init on first `#async` call. Avoids `kqueue: Too many open files` in test suites that construct many `App` / `Bridge` instances.

## [0.12.0] - 2026-05-21

### Added

- **Win32 Tray** — full implementation via `Shell_NotifyIconW` (show/hide/click dispatch), `CreatePopupMenu` + `TrackPopupMenu` for native menus, and `LoadImageW` for `.ico` icons. Runs on a dedicated `lune-tray` Isolated thread with a message-only HWND. PNG / SVG icons fall back to the system default with a warning (`.ico` only on Win32). `Tray.descriptor.platforms` promoted to `[:darwin, :linux, :win32]`. Bundled `assets/lune-logo.ico` for general use.
- **Per-capability platform gate** — `Descriptor#platforms` (default `[:darwin, :linux, :win32]`) filters caps out of the registry at construction time when the current OS isn't in the list. `DragOut` declares `[:darwin]`; `FileWatch` and `FileDrop` declare `[:darwin, :linux]`. Users no longer need manual `capabilities.exclude` entries for these on Win32.
- **Rejecting JS / TS stubs for platform-unavailable caps** — filtered caps still appear in `runtime.js`, with `Promise`-returning methods rejecting `LuneError("UNAVAILABLE_ON_PLATFORM", …)` and event subscriptions (`.on`/`.off`) doing a one-time `console.warn` + no-op. `runtime.d.ts` preserves the full signatures so cross-platform TypeScript type-checks identically. Capabilities override `unavailable_js_stub` / `unavailable_dts_stub` to opt in.
- **Info log on explicit `only:` skips** — `lune.yml` naming a capability that's not available on the current OS now emits a one-line `INFO` ack. Default-included caps skip silently. `validate()` no longer flags a known-but-unavailable name as "unknown capability".

### Changed

- **`Registry`** gains `platform_filtered` (the dropped caps) and tracks `@known_names` separately so `validate` still catches typos after the platform pre-filter. **`Runtime::Generator.{generate_runtime_js,generate_runtime_dts,write_js}`** accept a new `unavailable_caps` parameter and splice rejecting stubs into the output.
- **`Clipboard.readImage` / `writeImage` on Win32** now raise typed `Lune::Error("UNAVAILABLE_ON_PLATFORM", …)` from the capability's default callback (matching the platform-stub pattern), instead of bubbling a generic `NotImplementedError`. Text + HTML on Win32 unaffected.
- Removed the dead `rescue NotImplementedError` in `runner.cr`'s dev-mode stub install — platform-filtered caps are now absent from `registry.all`, so the rescue was only ever swallowing real bugs.

### Fixed

- **`Tray.setIcon("")` on macOS** now actually resets to the `●` default — the native fallback set `button.title` but didn't clear `button.image`, so the previously-loaded `NSImage` kept drawing over it. Win32 reset already worked.

## [0.11.2] - 2026-05-21

### Fixed

- **Duplicate method definitions in generated `runtime.js` / `runtime.d.ts`** — `Hotkeys.register` / `Hotkeys.unregister` appeared twice in both files, and `Shell.write` / `Shell.closeStdin` appeared twice in `runtime.d.ts`. Root cause: those capabilities registered the methods as bindings (which `to_js_stub` / `to_dts_sig` emit) and _also_ re-declared the same methods in `js_helpers` / `dts_helpers`, so the generator concatenated both into the same namespace block. Removed the redundant helper entries — bindings are the single source of truth now. The user-facing API is unchanged. Added regression specs that scan the generated runtime for exact-count occurrences so any future double-emission fails the suite.

### Changed

- **`Definition` / `Binding` gain `arg_transforms` and `ts_args`** — per-arg JS expression and TypeScript type overrides plumbed through `Definition → RuntimeBinding → Binding.to_js_stub / .dts_params`. Lets a capability JSON-stringify an array argument on the JS side and expose a precise TS type (e.g. `TrayMenuItem[]`) without resorting to a helper-override that re-declares the same method. `Tray.setMenu` and `DragOut.start` now use this and no longer emit a placeholder `arg0`-stub followed by an override (`setMenu(arg0) { … }` + `setMenu(items) { … JSON.stringify … }` collapsed to a single `setMenu(items) { … JSON.stringify … }` line). `ContextMenu.show` gained `arg_names: ["x", "y", "itemsJson"]` so its signature reads `show(x, y, itemsJson)` instead of `show(arg0, arg1, arg2)`.

## [0.11.1] - 2026-05-21

### Fixed

- **Win32 global hotkeys not firing** — `Msg.w_param` was declared as `LibC::ULong` (4 bytes on Windows LLP64) but `WPARAM` is `UINT_PTR` — 8 bytes on 64-bit. Crystal placed `w_param` at offset 12, reading from the 4-byte padding gap (always 0) instead of the real `wParam` at offset 16. `WM_HOTKEY` was arriving; only the ID lookup always returned nil. Fixed by changing to `UInt64`, which forces the correct 8-byte alignment and places `w_param` at offset 16.
- **`lune dev` orphaned npm/node/webview on Windows** — when `lune dev` exited (Ctrl-C, taskkill, crash, or even a clean shutdown), `Process.terminate` only killed the `cmd /c npm run dev` leader and left `npm.cmd`/`node.exe` holding the vite port. Restarting then iterated through 5173 → 5202+ looking for a free port. The compiled user-app (`.lune-dev`) also survived ungraceful kills, leaving the webview window with no parent. Two-part fix: (1) new `Native::ProcessGroup` puts `lune.exe` itself into a Win32 Job Object with `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`, so every descendant Windows creates is forced into the same job and the kernel atomically kills the whole tree when `lune.exe`'s handles are reaped. (2) On graceful exit, `dev.cr` shells out to `taskkill /F /T /PID <vite>` to walk the cmd/npm/node tree explicitly — `TerminateJobObject` would kill `lune.exe` too since it's a member. Crystal's per-child IOCP job (`SILENT_BREAKAWAY_OK`) coexists with ours via Win8+ nested-job rules. POSIX path is unchanged.
- **`lune build` / `lune init` / `lune doctor` failed to launch npm on Windows** — same root cause as the `lune dev` fix in v0.11.0: Crystal's `Process.run` bypasses cmd.exe, so `npm.cmd` / `yarn.cmd` / `pnpm.cmd` shims raise `File::NotFoundError`, and a user's `frontend.build: "npm run build"` in lune.yml fails the same way because PATHEXT only works through cmd.exe. Extracted the `cmd /c` wrapping into a single `LuneCLI::ProcessSpawn.wrap` helper used by every CLI entry point that spawns an external tool (`dev`, `build`, `init`, `doctor`). POSIX path is unchanged.
- **`lune dev` hot reload never fired on Windows** — `FileWatcher#collect_mtimes` used `Dir.glob(File.join(dir, "**", "*.cr"))`, which on Windows produced a pattern with `\` separators. Crystal's `Dir.glob` only accepts forward-slash patterns, so the call silently returned zero matches and the watcher never detected any change. Fixed by normalizing the pattern via `Path#to_posix`; results are converted back to native separators so callers comparing against `File.join` paths still match.
- **Nested embedded assets unreachable via their URL on Windows** — `Lune::Assets.embed_dir` walked the source tree via a compile-time `list_files` macro that emitted relative paths by slicing the matched `Dir.glob` result. On Windows, `Dir.glob` returns paths with `\` separators even when given a `/` pattern, so the generated routes ended up as `/nested\info.txt` and any nested asset returned 404 from the asset server. The macro now normalizes both the prefix and the matched paths to posix before slicing.
- **Specs failing on Windows due to CRLF auto-conversion** — Git's `autocrlf=true` (the default install setting on Windows) converted checked-in LF to CRLF on checkout, so `Lune::Assets.get("/index.html")` returned `"fixture index\r\n"` instead of `"fixture index\n"` and the vendored-webview SHA-pin spec saw different hashes on Windows vs the repo. Added a `.gitattributes` that pins all text files to LF (`* text=auto eol=lf`) and treats fixture content as binary so Git never rewrites it.

### Docs

- Fixed `lune-file-watch` thread table row in `how-it-works.md` — "When active" column now reads "FileWatch on macOS + Linux" so Windows readers don't assume the watcher thread spawns on their platform.
- Fixed DeepLink footnote `²` in `capabilities/index.md` — "Linux/Windows: cold-start (ARGV) only" was wrong; Linux has Unix-socket warm-start forwarding. Corrected to "Windows: cold-start (ARGV) only".
- Added `(macOS · Linux only)` qualifier to the FileWatch entry in the getting-started demo table.

## [0.11.0] - 2026-05-20

> **Windows runtime is blocked on upstream Crystal — but with a manual patch, real-hardware testing is now in progress.** All Win32 code type-checks cleanly on `windows-latest` CI, but full `crystal build` errors out with `undefined constant LibC::PidT` ([crystal#16929](https://github.com/crystal-lang/crystal/issues/16929)). The fix landed in master ([crystal#16933](https://github.com/crystal-lang/crystal/pull/16933)) and is targeted for **Crystal 1.21.0**. Lune itself can't drop below 1.20.1 because it depends on `Fiber::ExecutionContext`. With the one-line stdlib patch from `WINDOWS_SETUP.md` applied, the toolchain compiles and the demo runs end-to-end via `lune dev --debug`. Many capabilities are now verified working on real Windows hardware; gaps and partials are tracked in [`website/guide/windows-checklist.md`](website/guide/windows-checklist.md). See [WINDOWS_SETUP.md](WINDOWS_SETUP.md) for the toolchain bring-up.

### Added — Windows port (continued from v0.10.0)

- **`Lune::Native::Hotkeys` on Windows** — `RegisterHotKey` + `UnregisterHotKey` driven from a dedicated `Fiber::ExecutionContext::Isolated` thread that owns the `WM_HOTKEY` message pump (PeekMessageW @ 10 ms). Producer-side `register`/`unregister` calls from any fiber are marshalled through a Mutex-protected ops queue. Accelerator parser maps `Ctrl+Shift+K` / `Alt+F4` / `Cmd+Space` forms to (modifier flags, virtual-key code), with named-key coverage for space/return/tab/arrows/F1-F24.
- **`Lune::Native::Menu.show_context_menu` on Windows** — `CreatePopupMenu` + `AppendMenuW` + `TrackPopupMenu(TPM_RETURNCMD)`. Synchronous (no callback marshaling), with client-to-screen coord translation via `ClientToScreen`.
- **`Lune::Native::Notify.show` on Windows** — shells out to PowerShell + WinRT `ToastNotificationManager` with a hidden window. Title/body travel via env vars (`LUNE_TOAST_TITLE`/`LUNE_TOAST_BODY`) so command-line escaping isn't a concern; `SecurityElement.Escape` handles XML escaping. AUMID is `"Lune"` (unregistered), so on real hardware Windows silently drops the toast — see the "Fixed" entry below for the projection-load fix and `ROADMAP.md` for the AUMID-registration plan.
- **`Lune::Native::Clipboard.read` / `.write` on Windows** — text reads/writes now use direct Win32 (`OpenClipboard` + `SetClipboardData(CF_UNICODETEXT)` / `GetClipboardData`) instead of shelling out to `clip.exe` / `Get-Clipboard`. Removes the per-call PowerShell process spawn (~hundreds of ms) and dodges the webview-Isolated concurrency wall entirely. UTF-16 conversion happens in Crystal.
- **`DeepLink` Linux warm-start** — `Lune::DeepLinkIPC` opens a Unix-domain socket at `$XDG_RUNTIME_DIR/lune-<slug>.sock` (or `/tmp/…`). A second launch with a `myapp://…` URL on its command line forwards the URL to the primary instance over the socket and exits, instead of opening a duplicate window. Cold-start ARGV scanning still works as before. Auto-cleanup at process exit. macOS gets the same behaviour natively from NSApplication.
- **`.ico` embedding in `lune build`** — when `config.icon` is set to a `.ico` file, `lune build` generates a `.rc`, runs `rc.exe`, and passes the resulting `.res` to Crystal's MSVC linker via `--link-flags`. Skips silently with a warning if `rc.exe` isn't on `PATH` or the icon file is missing. PNG → ICO conversion is not done (Crystal stdlib has no PNG decoder); provide a `.ico` directly on Windows.

### Added — docs

- **Windows verification checklist** — new `website/guide/windows-checklist.md` walks through every capability that ships with Win32 support so you can tick off behaviour in a Windows VM.
- **Capability matrix updated** — `website/capabilities/index.md` now reflects the per-platform status of every capability after the v0.10.0 + v0.11.0 Windows work.

### Breaking

- **`opts.drop` → `opts.file_drop`** — the options block and its backing class now match the `file_drop` capability key (in `lune.yml`) and the `FileDrop` JS namespace. `Lune::Options::Drop` is renamed to `Lune::Options::FileDrop`. Migration is mechanical: replace `opts.drop do |d| … d.zone = … end` with `opts.file_drop do |fd| … fd.zone = … end`. Property names inside the block (`zone`, `value`, `on_drop`, `disable_webview_drop`) are unchanged.
- **`event_bus` capability renamed to `events`** — so the config key, capability class, JS namespace, and `app.events.emit` runtime accessor all share the same word. Migration: in `lune.yml`, replace `event_bus` with `events` in any `include`/`exclude` list; in Crystal user code, `Lune::Capabilities::EventBus` is now `Lune::Capabilities::Events`. The JS API (`Events.on/off/emit/once`) is unchanged.
- **`Lune::Native::Dialog` → `Lune::Native::Dialogs`** and **`Lune::Native::Notify` → `Lune::Native::Notifications`** — the internal native modules now match their capability and JS namespace names (`Dialogs`, `Notifications`). Only impacts code that reached past the capability layer directly into `Lune::Native::*`; user-facing JS APIs (`Dialogs.openFile`, `Notifications.show`) are unchanged. Underlying files renamed: `src/lune/native/dialog.cr` → `dialogs.cr`, `src/lune/native/notify.cr` → `notifications.cr`, plus the platform shims (`ext/native/{macos,linux}/{dialog,notify}.{m,c}` → `{dialogs,notifications}.{m,c}`).
- **DESCRIPTOR labels `"SQLite"` / `"KV"` → `"Sqlite"` / `"Kv"`** — descriptor labels now match the class casing and the JS namespace. The capability matrix and any other tooling that consumes `descriptor.label` (e.g. logging) will show the new casing.
- **Window frame persistence is now opt-in** — previously the window's position and size were always saved on close and restored on the next launch. New `opts.remember_frame` (`Bool`, default `false`) gates the behaviour. Existing apps that relied on auto-restore need to set `opts.remember_frame = true` (or `window.remember_frame: true` in `lune.yml`). Avoids surprising users whose monitor setup changed between sessions and would otherwise reopen at off-screen coordinates. macOS menubar mode keeps suppressing persistence unconditionally.

### Fixed

- **`Stream` capability on Windows** — multi-step fix. The WS server used to run inside a `Fiber::ExecutionContext::Isolated`, which blocks Channel ops on Windows and trapped the IOCP-backed accept fibers. Dropping the wrapper unblocked the listen path on Windows but the connection handlers still never fired: on Windows IOCP, the listening socket gets associated with whichever execution context first does I/O on it, so binding from the webview Isolated context and listening on a Parallel pool routed accept completions to the wrong IOCP. The Windows path now binds AND listens from the same spawned fiber on the default context, with the bound port signalled back via a 1-slot Channel. macOS/Linux keep the dedicated Parallel pool (own OS threads, no IOCP affinity to worry about under kqueue/epoll, and the pool stays scheduled while `wv.run` blocks the calling thread).
- **`Hotkeys` cross-Isolated Channel crash on Windows** — `Native::Hotkeys.register`/`unregister`/`unregister_all` all enqueued an op and then blocked on a per-op reply `Channel` to await the pump thread. Called from sync `Hotkeys.register`/`unregister` bindings (which run on the webview Isolated thread) or from the runner's shutdown loop (also webview Isolated), this raised "Concurrency is disabled in isolated contexts" — and on shutdown the cross-Isolated Channel wake also triggered an Invalid memory access. Two-part fix: (1) bindings now declare `async: true` so the callback runs on `@async_pool` (Parallel) where Channel ops are legal; (2) `unregister_all` is fire-and-forget on Win32 (sets `@@stopped` and returns), since the pump thread exits on its next tick and Windows reclaims any leftover `RegisterHotKey` registrations at process exit anyway.
- **`lune dev --debug` now propagates into the user-app binary** — previously `--debug` only flipped the CLI's own logger to debug. The spawned user-app binary (where the Lune library actually runs) re-initialised its logger at info. Now `lune dev` sets `LUNE_LOG=debug` in the child's environment when `--debug` is on, and `Lune.default_logger` reads `LUNE_LOG` (`debug`/`trace`/`warn`/`error`) on startup. Standalone Lune apps can also crank up logging via `LUNE_LOG=debug` without code changes.
- **`Shell.spawn` and `Notifications.notify` are now async bindings** — both callbacks did concurrency-sensitive work (Shell.spawn calls `app.async` 3× to start stdout/stderr/wait pumps; Notifications.notify shells out to PowerShell on Win32 via `Process.run`). As sync bindings, they ran on the webview Isolated thread on Windows and raised "Concurrency is disabled in isolated contexts". Declaring `async: true` routes the callback through `@async_pool` (Parallel) where Channel ops are legal. JS surface is unchanged — every Lune binding already returns a Promise on the JS side.
- **`lune dev` on Windows actually launches the app** — two blockers: (1) `npm run dev` failed to launch because Crystal's `Process.new` bypasses `cmd.exe` and only resolves `.exe` binaries, missing `npm.cmd` — wrapped in `cmd /c` under `flag?(:win32)`. (2) The runner's stub-install loop (which installs excluded capabilities purely to emit JS stubs) crashed on `FileWatch#install` because Win32 raised `NotImplementedError` eagerly. The loop now rescues `NotImplementedError` per-capability and logs at debug instead of taking down the whole app.
- **`Native::Dialogs.message` on Windows** — the type-code → variant mapping was wrong, so `Dialogs.message_warning` showed Yes/No, `Dialogs.message_error` showed OK/Cancel, and `Dialogs.message_question` showed only OK. Realigned the Win32 branch to the cross-platform contract: info / warning / error get a single OK with the appropriate icon; question gets Yes/No.
- **`Native::Notifications.show` Windows WinRT projection load** — the PowerShell script loaded `Windows.UI.Notifications` but not `Windows.Data.Xml.Dom`, so `New-Object Windows.Data.Xml.Dom.XmlDocument` failed with TypeNotFound and the whole script silently aborted. Loading both projections explicitly fixes the script (now exits 0 with no stderr). Caveat: the toast still doesn't visibly appear because the AUMID `"Lune"` isn't registered with the OS — tracked under "Windows toast notifications" in `ROADMAP.md`.
- **Window state persistence on Windows** — `Native::Window.get_frame` called after `wv.run` returned ran against an already-destroyed HWND (Windows tears the window down inside `webview_destroy` before returning), so `GetWindowRect` failed silently and Lune persisted the zero-initialised default `{0,0,0,0}`. Result: every Windows launch with persistence enabled would restore to the top-left, 0×0. Added `WindowState.start_tracker` (a 500 ms-polling fiber spawned right after the initial restore on Win32) that captures the frame while the HWND is still alive and self-terminates when `IsWindow(handle) == 0`. Also guards against persisting minimize-artefact frames. macOS/Linux keep the existing on-close save (their handles survive the shutdown sequence). Now gated by `opts.remember_frame` (see Breaking).
- **`file_drop` drop-detection dispatch on macOS** — the ObjC drag-callback used to schedule `dropCheck` through `wv.dispatch`, which queued behind any other dispatched work and lost the drop event during fast cursor movements. The callback now fires `dropCheck` directly from the ObjC side, removing the dispatch hop.

### Notes

- **Windows runtime blocked on Crystal 1.21+** — see header above. Once 1.21 lands, the per-capability walkthrough at [`website/guide/windows-checklist.md`](website/guide/windows-checklist.md) is the verification path.
- **Three Win32 compile-error fixes shipped late in the cycle** (commit `69e7599`) — `menu.cr` had `next.to_s` (treating a keyword as a value) and `Float32#to_long` (no such method); `dialog.cr` had a trailing-`while` modifier in a context Crystal rejects. Caught only when an actual `cl.exe`/Crystal build was run on Windows.
- **Windows status** — per-capability "verified / partial / not implemented" lives in [`website/guide/windows-checklist.md`](website/guide/windows-checklist.md); the path to parity (with the underlying Win32 API needed per item) is in [`ROADMAP.md`](ROADMAP.md). Both are kept current as gaps land — this changelog deliberately doesn't duplicate them.

## [0.10.0] - 2026-05-20

### Added

- **Explicit `:win32` stubs across native modules** — every Lune::Native method that has both a darwin and a linux implementation now also has an explicit `{% elsif flag?(:win32) %}` branch that raises `NotImplementedError` with a clear "(v0.10.0 backlog)" message. Affects `Dialog.*`, `Clipboard.read_html/write_html/read_image/write_image`, `Notify.show`, `Screen.info`, `Tray.show/hide/set_icon/set_menu`, `FileWatch` (start/add_watch/remove_watch), `Hotkeys.init/register/unregister`, `Window.disable_webview_drop`/`setup_file_drop`, and `DeepLink.install`. Methods that have always been macOS-only (window chrome customisation, drag-out, `Menu.*`, `Tray.popup_menu`/`set_right_click_cb`/`button_screen_rect`) remain implicit no-ops on Win32, matching the current Linux behaviour. Lets users running on Windows get a precise "not implemented yet" error per capability instead of silent breakage; lifecycle-tied callsites in the runner (`Window.set_frame`/`get_frame`/etc.) keep no-op behaviour so apps still launch.
- **`Clipboard` Linux branches split out** — previously `read_html`/`write_html`/`read_image`/`write_image` used `{% else %}` as the Linux/xclip path, which silently fell through on Win32 too. Linux paths are now under `{% elsif flag?(:linux) %}` so Win32 doesn't accidentally try to spawn `xclip`.

### Fixed

- **`System.openUrl` on Windows** — the default open-URL handler used to fall through to `xdg-open` on every non-darwin OS, which silently broke on Windows. Now an explicit `:win32` branch runs `cmd /c start "" <url>`, so `System.openUrl("https://example.com")` actually opens the user's default browser on Windows.
- **`System.environment` os string under `:win32`** — the previous `{% else %}` branch lied "windows" on any non-darwin/non-linux target (including hypothetical BSDs). Now `:win32` is matched explicitly and the fallthrough returns `"unknown"`.
- **`lune build` output path on Windows** — `Commands::Build#output_path_for` now appends `.exe` on `:win32`, matching what Crystal actually produces. Without it, `lune run`'s validation step would refuse to launch the freshly built binary because it looked for `build/bin/myapp` while Crystal had emitted `build/bin/myapp.exe`.
- **`Lune::Native::Window` basics on Windows** — `minimize`, `maximize`, `center`, `set_title`, `set_size`, `get_frame`, and `set_frame` now drive the HWND directly via `user32.dll` (`ShowWindow`, `MoveWindow`, `SetWindowTextW`, `GetWindowRect`, `SetWindowPos`, `GetSystemMetrics`). Previously these silently no-op'd on Win32, so the runner's `WindowState` restore/save cycle and any `Window.setSize`/`Window.setTitle` JS calls did nothing. The HWND comes from the webview shard's `wv.native_handle(UI_WINDOW)`.
- **`Lune::Native::Screen.info` on Windows** — implemented via `GetSystemMetrics(SM_CX/CYSCREEN)` for size and `GetDpiForSystem` for the DPI scale factor (`dpi / 96.0`). Requires Windows 10 1607+ for the DPI API; older Windows will report scale `1.0`.
- **`Lune::Native::Dialog` on Windows** — `open_file`, `open_dir`, `open_files`, `save_file`, and `message` all routed to native Windows dialogs: `GetOpenFileNameW` / `GetSaveFileNameW` (comdlg32), `SHBrowseForFolderW` + `SHGetPathFromIDListW` (shell32), and `MessageBoxW` (user32). Multi-select uses the standard null-separated `[dir, file1, file2, …]` layout and reassembles full paths. Replaces the previous `NotImplementedError` stubs.
- **`Lune::Native::Clipboard.read_html` / `write_html` on Windows** — implemented via `OpenClipboard` + `GetClipboardData`/`SetClipboardData` with the registered `CF_HTML` format. Writes wrap the fragment in the standard "Version:0.9 / StartHTML / EndHTML / StartFragment / EndFragment" header envelope; reads parse `<!--StartFragment-->...<!--EndFragment-->` markers to extract just the user-visible fragment. `read_image`/`write_image` remain as explicit `NotImplementedError` raises pending PNG-to-DIB conversion.

### Internal

- **Windows compile check in CI** — `specs.yml` now type-checks `src/lune_cli.cr` on `windows-latest` without `-D lune_native_test_mock`, so the real `flag?(:win32)` code paths are verified on every push. The previous mocked compile-check is kept so the test surface is still exercised on Windows too.
- **`DeepLink` Linux gap flagged** — `website/capabilities/deep-link.md` claims macOS · Linux support, but the native code has no `:linux` branch (silent no-op). Tracked separately from the Windows port; for now the new `:win32` raise keeps Windows on par with the docs' documented behaviour.

## [0.9.0] - 2026-05-19

### Added

- **Menubar-only mode** — `opts.mac { |m| m.menubar_mode = true }` turns the app into a macOS status-bar utility. Hides the dock icon (`NSApplicationActivationPolicyAccessory`), starts the window hidden, auto-hides on focus loss (`NSWindowDidResignKeyNotification`), and shows the tray icon at boot via `opts.tray.auto_show`. Click-to-window behavior is opt-in via `opts.tray.toggle_window_on` — keep it empty for Docker-style menu-driven apps, set `[:left_click]` for Bartender/MeetingBar-style popovers. Window frame is never saved/restored in menubar mode; position is recalculated from the tray icon on each toggle. macOS only.
- **`opts.tray.toggle_window_on : Array(Symbol)`** — lists which tray clicks toggle the app window. Valid values: `:left_click`, `:right_click`. Default `[]`. When listed, the click positions the window centered below the tray icon (macOS) and toggles visibility.
- **`opts.tray.auto_show : Bool`** — shows the tray icon at boot without needing a JS `Tray.show("")` call. Default `false`; auto-enabled by `mac.menubar_mode`.
- **`opts.tray.on_right_click : (-> Nil)?`** — Crystal callback for right-click (or Ctrl-click), symmetric to `on_click`. Setting it takes full takeover of right-click behavior.
- **`Tray.popupMenu()`** (JS) / `Lune::Native::Tray.popup_menu` (Crystal) — programmatically opens the last-set menu. Use it from custom click handlers, keyboard shortcuts, or any other trigger; no-op if no menu is set.
- **Unified tray click model** — per click direction, the first matching rule wins: (1) user override, (2) `toggle_window_on` listed → toggle, (3) menu set → popup, (4) emit `trayEvent`. Replaces the previous asymmetric model where right-click was silent without a menu and assigning a menu killed the click callback.
- **`Window.show` / `Window.hide`** — exposed to JS via the `window` capability. Useful for custom menubar toggle logic and any scenario where the Crystal side shouldn't own visibility.

### Breaking (tray)

- **`trayEvent` payload changed** — left-click default payload was `"click"`, now `"left_click"`. Right-click without a menu used to be silent; now emits `"right_click"`. Update JS listeners: `if (id === "click")` → `if (id === "left_click")`.
- **`menubar_mode` no longer auto-toggles the window on left-click** — the previous version pre-filled `opts.tray.on_click` with a window-toggle. The new version separates window state (menubar_mode) from click behavior (toggle_window_on). To get the old behavior, add `opts.tray.toggle_window_on = [:left_click]`.

- **`windows` capability** — open additional native windows from JavaScript. `Windows.open({ title, url, width, height })` creates a new window sharing all active capability bindings, and resolves with an opaque handle. `Windows.close(id)` closes it; `Windows.list()` returns all open handles. A `window_closed` event fires on OS × or programmatic close. Every capability works identically in secondary windows — `stream` connects as a client to the main window's WebSocket server, `file_drop`, `context_menu`, `hotkeys`, and all others are fully active.
- **`sqlite` capability** — embedded SQLite via `crystal-lang/crystal-sqlite3`. `Sqlite.open(path)` returns a handle (`":memory:"` for in-process, absolute path for persistent). `Sqlite.exec(db, sql, params)` runs writes and returns `{ changes, lastInsertId }`; `Sqlite.query(db, sql, params)` runs reads and returns rows as objects. `Sqlite.close(db)` releases the handle. All open databases are closed on quit.
- **`hotkeys` capability** — system-wide keyboard shortcuts that fire even when the app is not focused. `Hotkeys.register("Cmd+Shift+K")` registers a shortcut; listen via `Events.on("hotkey", cb)`. `Hotkeys.unregister(accelerator)` removes it; all are released on quit. macOS uses Carbon `RegisterEventHotKey`; Linux uses `XGrabKey`.
- **`Shell.list()`** — returns pids of all currently running processes. Use it to hydrate secondary windows that didn't spawn the processes: call `Shell.list()` on mount, then `Shell.listen(pid, ...)` to receive future output.
- **`Shell.write(pid, text)` / `Shell.closeStdin(pid)`** — write text to a running process's stdin, and close it to send EOF. Enables interactive programs: shells, REPLs, `sort`, `wc`, and anything else that reads from stdin.
- **`mac.hide_traffic_lights`** — hides the close/minimise/zoom buttons. Combined with `full_size_content`, `hide_title`, `transparent`, and CSS drag zones, this enables fully chrome-free custom windows on macOS.
- **`kv` capability** — persistent JSON key-value store scoped per app. `Kv.set(key, value)` / `Kv.get(key)` / `Kv.delete(key)` / `Kv.has(key)` / `Kv.keys()` / `Kv.clear()`. Values are any JSON-serialisable type and survive app restarts. Stored in the platform-standard app data directory (`~/Library/Application Support/<app>` on macOS).

### Breaking

- **`app.emit/on/once/off` → `app.events.*`** — event bus is now accessed via `app.events`: `app.events.emit`, `app.events.on`, `app.events.once`, `app.events.off`. The flat methods are removed.
- **`app.stream_send/stream_on/stream_off` → `app.stream.*`** — stream is now accessed via `app.stream`: `app.stream.send`, `app.stream.on`, `app.stream.off`. `app.stream_sender` is replaced by `app.stream.sender`.

## [0.8.0] - 2026-05-19

### Added

- **`shell` capability** — spawn child processes and stream `stdout`/`stderr` to the frontend in real time over the WebSocket stream. `Shell.spawn(command, args)` returns a pid; subscribe via `Shell.listen(pid, { stdout, stderr, exit })`. `Shell.kill(pid)` sends SIGTERM. `Shell.run(command, args?)` is a convenience wrapper that resolves with `{ stdout, stderr, code }` once the process exits. Hard-depends on `stream`; auto-disabled with a warning when `stream` is excluded.
- **`Stream` capability** — bidirectional, ordered, low-latency WebSocket IPC stream. Use `app.stream_send(name, data)` from Crystal and `Stream.on` / `Stream.send` from JavaScript for high-frequency or continuous data flows (tickers, log tails, LLM token output) where the event bus's per-call `evaluateJavaScript` overhead would become a bottleneck. Auto-reconnects on disconnect; excludable via `lune.yml`.
- **`file_watch` capability** — monitor files and directories for filesystem changes. Call `FileWatch.watch(path)` / `FileWatch.unwatch(path)` from JavaScript; subscribe to change events with `FileWatch.on(cb)`. Events carry `{path, kind}` where `kind` is `"modified"`, `"created"`, `"deleted"`, or `"renamed"`. Backed by kqueue (`EVFILT_VNODE`) on macOS and inotify on Linux — no polling, no extra system dependencies. Hard-depends on `event_bus`; automatically disabled with a warning if `event_bus` is excluded.
- **`opts.file_watch.debounce`** — configurable debounce window (default 50 ms) that collapses the burst of raw OS events produced by a single editor save into one logical event per path. Set to `0.milliseconds` to receive raw events.

### Fixed

- **`Process.run` / `Shell.run` hung indefinitely on Unix** — Crystal's `signal-loop` fiber lives in the default execution context (the main thread). On macOS/Linux the main thread is permanently inside Cocoa's / GTK's run loop via `wv.run`, so that fiber never gets to run and SIGCHLD signals queue up unread — `Process#wait` then blocks on a channel that is never fed. `Shell.run` hung forever and `Shell.spawn`'s `exit` event never fired; `System.openUrl` was silently broken too (callers don't `await` so the hang was invisible). The runner now spawns a dedicated `lune-sigchld-pump` Isolated execution context that polls `Crystal::System::SignalChildHandler.call` every 10 ms, draining reaped children regardless of main-thread availability.
- **macOS 26+ crash on app close** — `deplete_run_loop_event_queue` in the webview destructor called `nextEventMatchingMask:` from a non-main OS thread. macOS 26 (Tahoe) began enforcing main-thread-only for that call; the resulting ObjC exception propagated as `std::terminate` → `SIGABRT`. Fixed upstream in `naqvis/webview` (`fff6c392`); the fix is now pulled in directly without a local patch.
- **File-drop JSON parse error swallowed** — the native drop callbacks now wrap the entire parse + dispatch in a typed `rescue JSON::ParseException | TypeCastError | KeyError`, preventing a hard crash if the ObjC layer sends unexpected data.
- **Linux inotify buffer overread** — the inotify event loop now validates `buf.size >= sizeof(InotifyEvent)` and `step <= buf.size` before advancing the pointer; a short read or an oversized `ev.len` could previously walk past the buffer end.
- **Darwin kevent fd leak on registration failure** — `FileWatch.add_watch` now registers the kevent before storing the fd in the watch map, and closes the fd if `kevent()` returns an error. Previously a failed registration left the fd recorded but unwatched (silent no-op).
- **Tray `setMenu` crash on malformed input** — the `set_menu` bridge callback now uses safe JSON navigation and wraps the parse in a typed rescue; a missing `id`/`label` key or invalid JSON previously caused a hard `TypeCastError` crash.
- **File-drop callback crash on unexpected JSON** — the native drop callbacks on both macOS and Linux now use `?.try(&.as_i?)`/`?.try(&.as_s?)` with safe defaults; malformed JSON from the native layer previously raised `TypeCastError`.
- **Bridge TOCTOU race in `dispatch_result`** — the closed guard is now checked both before queuing the dispatch _and_ inside the queued block, closing the window where the webview could be torn down between the pre-dispatch check and block execution.
- **`WindowState.load_from` bare rescue** — replaced with a typed rescue on `JSON::ParseException | TypeCastError | File::Error | IO::Error`; failures now log a warning instead of silently returning nil.
- **Stream silent message-parse failure** — the bare `rescue` in the WebSocket message handler now captures and logs the exception at debug level.
- **Clipboard command failures silently ignored** — `DEFAULT_READ` and `DEFAULT_WRITE` now check `Process.run` exit status and log a warning on failure; missing binaries (`xclip`, `pbpaste`) now rescue `File::Error | IO::Error` and log instead of crashing or returning empty silently.
- **`file_watch` double-start in dev mode** — in dev mode the runner called `install` twice on the same capability instances (once for the real app, once to collect bindings for JS codegen). `FileWatch` opened two kqueue/inotify fds and the second fiber held a reference to a stub app with no bridge, so all file events were silently dropped. `start` is now idempotent, and the dev-mode binding collection pass skips capabilities already installed for the real app.
- **`app.emit` crash when `event_bus` excluded** — calling `app.emit` with the event bus capability disabled threw `TypeError: crystalEmit is not a function` in JS. The Crystal side now guards the call, and no-op JS stubs are injected for `crystalEmit`, `on`, `off`, and `jsEmit` so frontend code that references them doesn't throw.
- **Stream JS stubs when `stream` excluded** — `stOn`, `stOff`, and `stSend` are stubbed as no-ops when the stream capability is inactive, preventing crashes in frontend code that references them unconditionally.
- **Drop-zone highlight flickering** — `dragPos` previously removed the `lune-drop-target-active` class and re-added it on every drag-move event, restarting any CSS transition on each tick. The class is now only toggled when the active element actually changes, eliminating the flicker and fixing cases where slow CSS transitions never completed.

### Internal

- **macOS 26+ webview fix upstreamed** — our `[NSThread isMainThread]` guard was merged into `naqvis/webview` master (`fff6c392`). The local `patch_webview.sh` and its `{% system(...) %}` compile-time invocation are removed; `shard.yml` pins to the upstream commit directly.
- **Capability architecture** — each capability now declares a `Descriptor` (id, label, deps, soft_deps, core) and opts into lifecycle phases via modules (`Capability::Bindable`, `Capability::WebviewInject`, `Capability::Lifecycle`) rather than overriding no-op base methods. Context structs (`SetupCtx`, `BindCtx`, `WebviewCtx`) replace scattered argument lists. `name` derives from `descriptor.id` — no per-capability override needed. The registry runs a `setup` pass so handle- and options-dependent capabilities pull state from context instead of constructor injection. `Registry#resolve` applies include/exclude config, cascade-disables capabilities whose hard deps are inactive (with logged warnings), emits soft-dep warnings, and topologically sorts the result. The runner dispatches through `is_a?` phase checks and calls `shutdown` on `Lifecycle` capabilities after `wv.run`. `App#install(cap : Capability)` added as a convenience for installing capabilities from user code.
- **Binding boilerplate reduced** — `Dialogs` message variants, `Clipboard` read/write registrations, and `Window` zero-arg operations (minimize/maximize/center) are now table-driven loops; the four identical `message_*` blocks, six identical clipboard blocks, and three identical window blocks each collapse to a single descriptor array. No behaviour change.
- **`Runner#webview` decomposed** — capability webview-init (sentinel injection + stub JS for excluded capabilities) extracted to `inject_capability_init`; the navigation branch (html/url/dev_url/assets) extracted to `setup_navigation`. The `webview` body drops from ~100 lines to ~60.
- **`Generator` JS/DTS grouping deduplicated** — `generate_runtime_js` and `generate_runtime_dts` shared identical 10-line namespace-grouping logic; extracted to `namespace_groups(&helper_fn)` called with `&.js_helpers` / `&.dts_helpers`.
- **`Generator` namespace body extracted** — the `String.build` block that assembles per-namespace binding stubs and helper snippets was duplicated in `generate_runtime_js` and `generate_runtime_dts`; extracted to `namespace_body(ns, binding_groups, helper_groups, &method_fn)`.
- **`Lune.run` build-mode logic extracted** — the `{% if flag?(:build_mode) %}` branch of the `run` macro is now a plain `_build_run(app)` method, making the macro body trivial and the build path independently readable and testable.
- **`Bridge#dispatch_result` error code extraction** — replaced `ex.is_a?(Lune::Error) ? ex.code : "error"` with `ex.as?(Lune::Error).try(&.code) || "error"`, letting the compiler handle the type narrowing.
- **`FileWatch::WatchMap`** — Linux inotify's two manually-synced bidirectional maps (`@watch_ids : Hash(Int32, String)` and `@path_to_wd : Hash(String, Int32)`) are now encapsulated in a private `WatchMap` class whose `add`/`remove`/`path_for`/`includes?`/`clear` methods guarantee the maps stay in sync.
- **`FileWatch#maybe_emit`** — Darwin (kqueue) and Linux (inotify) fiber loops duplicated the debounce guard and `app.emit` call; extracted to a private `maybe_emit` helper shared by both platforms.

## [0.7.1] - 2026-05-19

### Fixed

- **Main-thread crash** — all native AppKit (macOS) and GTK (Linux) UI calls — dialogs, window controls, tray, context menus — now dispatch synchronously to the main thread when invoked from a background fiber. Eliminates the intermittent `NSInternalInconsistencyException: nextEventMatchingMask should only be called from the Main Thread!` crash.

### Changed

- **`async: true` bindings use a shared thread pool** — async binding callbacks and `app.async` blocks now spawn fibers into a `Fiber::ExecutionContext::Parallel` pool instead of creating a new OS thread per call. Reduces overhead for apps that fire async bindings frequently.

## [0.7.0] - 2026-05-18

### Breaking

- **Namespaced JS API** — `runtime.js` now exports PascalCase namespace objects with camelCase methods instead of flat functions. `quit()` → `System.quit()`, `clipboardRead()` → `Clipboard.read()`, `screenInfo()` → `Screen.info()`, `on()` → `Events.on()`, etc. A `runtime` default export bundles all namespaces. All TypeScript declarations updated to match.
- **`lifecycle` capability renamed to `system`** — update `lune.yml` (`lifecycle` → `system`); JS namespace is now `System` (was `Lifecycle`); bridge IDs changed from `__lune.lifecycle.*` to `__lune.system.*`.
- **`LuneError` class** — rejected promises now reject with `LuneError extends Error` instead of a plain object. `err.code` is the machine-readable error type; `err.message` replaces the old `err.error` field. `err instanceof LuneError` and `err instanceof Error` both work. `runtime.d.ts` exports `LuneError` as a class declaration.
- **`drop.enabled` removed** — file drop is now activated solely by including `file_drop` in the `capabilities` list in `lune.yml`. `opts.drop` configures behaviour only (`zone`, `value`, `on_drop`, `disable_webview_drop`). Passing `d.enabled = true` no longer compiles.
- **`FileDrop.on` / `FileDrop.off`** — renamed from `onFileDrop` / `onFileDropOff`.
- **Context menu API changed** — `setContextMenu(items)` / `clearContextMenu()` / `onContextMenu(cb)` replaced by the namespaced `ContextMenu.set(items)` / `ContextMenu.clear()` / `ContextMenu.onSelect(cb)`.
- **`Lune::Capability` refactored to abstract class** — was a plain value object; now an abstract base class with `name`, `install(app)`, `init_webview(wv, handle, app)`, `js_helpers`, and `dts_helpers`. All concrete capability classes inherit from it.
- **`Capabilities::Registry` now instance-based** — `Registry.all(handle, ...)` class method replaced by `Registry.new(handle, options).all` / `.active(config)` / `.validate(config)`.

### Added

- **`lune dist`** — new CLI command that packages the built app for distribution. On macOS produces a DMG via `hdiutil` with an `/Applications` symlink; if `mac.notarize: true` and credentials are set, submits to Apple's notary service and staples the ticket. On Linux assembles an AppDir and runs `appimagetool` to produce a self-contained `.AppImage`. Use `--skip-notarize` to skip notarization on macOS.
- **`mac.notarize`** — new `lune.yml` option (`Bool`, default `false`). Enables automatic notarization and stapling in `lune dist`.
- **`mac.entitlements`** — new `lune.yml` option (`String?`). Path to a custom entitlements plist passed to `codesign` during `lune build`. When omitted, Lune generates a minimal default that satisfies WKWebView under hardened runtime.
- **`mac.bundle_id`** — new `lune.yml` option (`String?`). Overrides the `CFBundleIdentifier` in `Info.plist` (default: `dev.lune.<app_name>`).
- **Deep links / `url_schemes`** — registers OS-level URL handlers. `lune build` injects `CFBundleURLTypes` into `Info.plist` (macOS); `lune dist` injects `MimeType` entries into the `.desktop` file (Linux). The app receives URLs via `DeepLink.on(cb)` in JS. macOS uses `NSAppleEventManager`; Linux reads the URL from `ARGV` on startup.
- **`name` drives artifact naming** — `lune.yml`'s `name` field now controls the output artifact name (`build/bin/<name>.app`, `build/bin/<name>.dmg`). `CFBundleName` in `Info.plist` also uses `name`. Previously the name was always derived from `app_entry`.
- **Rich clipboard** — `Clipboard.readHtml()`, `Clipboard.writeHtml(html)`, `Clipboard.readImage()` (returns `data:image/png;base64,...` or `""`), and `Clipboard.writeImage(dataUrl)`. macOS backed by `NSPasteboard`; Linux backed by `xclip`.
- **Context menus** — `ContextMenu.set(items)` / `ContextMenu.clear()` / `ContextMenu.onSelect(cb)` register a native right-click menu from JS. The `contextmenu` event is intercepted automatically; the selected item `id` is delivered to the callback. Items support `id`, `label`, `enabled`, and `separator`. macOS backed by `NSMenu popUpMenuPositioningItem:atLocation:inView:`.
- **Drag-out** — `DragOut.start(paths)` initiates a native macOS drag session from JS. Call it from a `pointerdown` handler to let users drag local files from the app into Finder or another drop target. Backed by `NSView beginDraggingSessionWithItems:event:source:`.
- **Distribution guide** — new website page documenting the full signing, packaging, and notarization workflow.

### Changed

- **Bridge IDs** — internal WebView binding identifiers changed from `runtime.__lune.<camelCase>` to `__lune.<capability>.<snake_case>` (e.g. `runtime.__lune.clipboardRead` → `__lune.clipboard.read`). Affects only code calling `window[id]` directly.
- **`capabilities` refactored to `include`/`exclude` struct** — `capabilities:` in `lune.yml` is now a map with optional `include` and `exclude` keys instead of a flat array. `include` restricts to the listed capabilities; `exclude` removes from whatever `include` resolved to. Both keys accept `"*"` or `"all"` as wildcards. Omitting `capabilities:` entirely still exposes everything.
- **Capabilities operate at group granularity** — `include`/`exclude` target whole capability groups (e.g. `system`, `clipboard`). Individual function names are not valid and log a warning.
- **Dev vs build enforcement** — in dev mode the bridge is filtered but `runtime.js` always contains all helpers so hot-reload keeps working. In build mode both are filtered; importing an excluded function is a hard bundler error.
- **Startup warnings for unknown capability names** — any unknown name in `include` or `exclude` logs a warning before the window opens.
- **Dev warning for orphan config** — in debug mode, logs a warning if capability options are configured but the capability is not active.
- **Tray auto-emits events** — `opts.tray` callbacks are now optional. When the `tray` capability is active, icon clicks emit `"trayEvent"` with `"click"` and menu item clicks emit `"trayEvent"` with the item `id`. Override `t.event` for a custom event name, or set `t.on_click`/`t.on_menu_click` for full Crystal-side control.
- **`Tray.setMenu` accepts an array** — auto-serialises items to JSON; `Tray.setMenu([{ id, label }])` works without manual `JSON.stringify`.
- **`disable_context_menu` demoted** — no longer a `Lune::Capability` subclass; handled as a plain option in `Runner`. `opts.disable_context_menu` unchanged.
- **`keyboard_shortcuts` demoted** — Cmd/Ctrl+C/V/Z/etc. JS injection inlined into `Runner`. Always active; not a toggleable capability.
- **`navigation` demoted** — `on_navigate` JS injection inlined into `Runner`. `opts.on_navigate` unchanged.
- **`drag_zone` demoted** — window drag zone setup inlined into `Runner`. `opts.drag.zone` / `opts.drag.value` unchanged.
- **New core capabilities** — `EventBus`, `KeyboardShortcuts`, `ContextMenu`, `Navigation`, `DisableContextMenu`, `DragZone`, and `FileDrop` are now first-class `Lune::Capability` subclasses. Previously their JS was injected as raw strings from `Runner`. They participate in `include`/`exclude` like any other capability.
- **`runtime/scripts.cr` deleted** — JS initialisation code moved into `init_webview` on the respective capability classes.
- **`Runtime::Generator` now capability-aware** — `generate_runtime_js` and `generate_runtime_dts` collect `js_helpers`/`dts_helpers` from each capability, replacing hardcoded helper blocks.
- **`runner.cr` simplified** — install and webview-init phases are now `active.each { |cap| cap.install(@app) }` / `active.each { |cap| cap.init_webview(...) }` loops; feature-specific setup methods removed.
- **Generated `App.js` stubs use named parameters** — stubs now emit `Add(arg0, arg1)` / `Add(n, label)` instead of `Add(...args)`.
- **`opts.debug` respects build mode** — uses `{{ flag?(:lune_dev) }}` so release builds correctly report `BUILD: release`.
- **Makefile demo targets renamed** — `dev`/`app`/`run` → `demo-dev`/`demo-app`/`demo-run`. New targets: `demo-release`, `demo-dist`, `demo-deploy`.
- **Demo** — new Capabilities view shows which runtime functions are available in the current build.
- **Website docs rewritten** — `guide/runtime.md`, `guide/events.md`, `guide/deep-links.md`, `guide/how-it-works.md`, `guide/typescript.md`, `configuration.md`, and `getting-started.md` updated to the new namespaced API.

---

## [0.6.2] - 2026-05-17

### Fixed

- **File drop zone hover** — `lune-drop-target-active` now correctly highlights the drop zone element even when the cursor is over a child element (text, icon, etc.). Previously `getComputedStyle` matched inherited CSS custom property values on child elements, adding the active class to the wrong node. Detection now uses `el.style` (inline style only), consistent with the documented API.
- **macOS drag position updates** — zone highlights during a file drag are snappy and glitch-free. The previous implementation routed each drag-move through `wv.dispatch { wv.eval(...) }` — a double-async hop (Crystal GCD dispatch → WKWebView eval queue) that let stale position evals queue up and fire out of order. The native `LuneDropView` now calls `evaluateJavaScript:completionHandler:` directly with a coalescing gate: at most one eval is in-flight at a time; if the cursor moved while waiting, the latest position flushes immediately on completion.
- Same `el.style` fix applied to window drag zones (`--lune-draggable`), preventing false matches on children inside a drag-handle container.

---

## [0.6.1] - 2026-05-17

### Added

- `mac.sign` in `lune.yml` — code-signing identity applied via `codesign --force --deep --options runtime` after `lune build`. Enables `UNUserNotificationCenter` in production builds.
- Runtime notification routing now uses the Security framework to detect a certificate-backed Apple signature (Team Identifier present) instead of checking for a bundle identifier. Ad-hoc and unsigned builds fall back to `osascript`.

### Fixed

- Makefile `dev` / `app` / `run` / `clean` targets pointed at the old `exampleapp/` path; updated to `demo/`.

---

## [0.6.0] - 2026-05-17

### Added

- `opts.menu { |m| }` — user-configurable macOS menu bar. Replaces the default menu when set; falls back to the standard App + Edit + Window menus when omitted.
  - `m.app_menu` / `m.edit_menu` — role menus wired to native macOS selectors (About, Services, Quit; Undo, Redo, Copy, Paste, etc.).
  - `m.submenu(label) { |f| }` — top-level custom submenu with its own item builder.
  - `f.item(label, shortcut:, enabled:) { }` — text item with optional keyboard shortcut and per-item callback block.
  - `f.separator` — horizontal separator.
  - `f.checkbox(label, checked:, shortcut:) { |on| }` — toggle item; block receives new `Bool` state.
  - `f.radio(label, selected:, shortcut:) { }` — radio item; adjacent radio items form a group automatically.
  - `f.submenu(label) { }` — nested submenu at any depth.
- `app.update_menu` — re-applies the current menu after mutating `Options::Menu::Item` properties (`label`, `enabled`, `checked`) at runtime.
- `app.set_menu { |m| }` — replaces the entire menu bar at runtime.
- `Lune::Options::Menu::Shortcut` — pure-Crystal shortcut parser: converts strings like `"cmd+n"`, `"cmd+shift+z"`, `"cmd+f1"` into the key character and `NSEventModifierFlags` bitmask used by `NSMenuItem`.
- **Class-based menu API** — subclass `Options::Menu::Group` or `Options::Menu` for apps with complex menus or where keeping state and callbacks in a dedicated class is preferred.
  - `m.submenu(group : Options::Menu::Group)` — pass a pre-built group instance instead of a block.
  - `opts.menu(m : Options::Menu)` — assign a pre-built menu instance directly.
  - Both styles (inline block and class-based) can be mixed freely.

### Changed

- **Demo app** (`demo/`, previously `exampleapp/`) — rebuilt frontend on the Vue 3 template (`lune init -t vue`): Single File Components, grouped sidebar with icons, `useLuneEvent` composable for auto-cleanup, animated starfield background, Welcome hero with orbital animation, live environment/screen stats, and a redesigned ping/pong display with per-round index and latency. Tray icon show/hide replaced with a toggle switch.
- **Options namespace reorganisation** — all option sub-types are now nested under `Lune::Options`:
  - `Lune::MacOptions` → `Lune::Options::Mac`; appearance enum moved to `Lune::Options::Mac::Appearance`
  - `Lune::DropOptions` → `Lune::Options::Drop`
  - `Lune::DragOptions` → `Lune::Options::Drag`
  - `Lune::TrayOptions` → `Lune::Options::Tray`
  - `Lune::MenuOptions` → `Lune::Options::Menu`
  - `Lune::MenuItem` → `Lune::Options::Menu::Item`
  - `Lune::MenuGroup` → `Lune::Options::Menu::Group`
  - `Lune::MenuShortcut` → `Lune::Options::Menu::Shortcut`
  - `src/lune/options.cr` reorganised into `src/lune/options/` folder with one file per component group.

---

## [0.5.1] - 2026-05-16

### Breaking

- **Grouped options now use nested blocks** — `opts.drop { |d| }`, `opts.drag { |d| }`, `opts.tray { |t| }`, and `opts.mac { |m| }` replace the old flat properties on `Options`. Direct setter calls (e.g. `opts.on_tray_click =`, `opts.drag_zone =`, `opts.enable_file_drop =`) no longer exist.
  - `opts.on_tray_click` → `opts.tray { |t| t.on_click = ... }`
  - `opts.on_menu_click` → `opts.tray { |t| t.on_menu_click = ... }`
  - `opts.enable_file_drop` → `opts.drop { |d| d.enabled = true }`
  - `opts.on_file_drop` → `opts.drop { |d| d.on_drop = ... }`
  - `opts.drop_zone` / `opts.drop_value` → `opts.drop { |d| d.zone = ...; d.value = ... }`
  - `opts.disable_webview_drop` → `opts.drop { |d| d.disable_webview_drop = true }`
  - `opts.drag_zone` / `opts.drag_value` → `opts.drag { |d| d.zone = ...; d.value = ... }`

### Added

- `Lune::DropOptions` class — groups file drop configuration (`enabled`, `disable_webview_drop`, `zone`, `value`, `on_drop`).
- `Lune::DragOptions` class — groups window drag-handle configuration (`zone`, `value`).
- `Lune::TrayOptions` class — groups tray callbacks (`on_click`, `on_menu_click`).
- `Options` default values are now declared at the property level — `initialize` is a single no-op, removing the large explicit initializer.

---

## [0.5.0] - 2026-05-16

### Breaking

- **Manual `crystal build` now requires `-Dpreview_mt -Dexecution_context`** — `lune dev` and `lune build` pass both flags automatically, but any manual compilation will fail without them.
- **`async: true` binding callbacks now run in true parallel on separate OS threads** — if multiple async bindings access shared Crystal state concurrently, that state must be thread-safe (use `Mutex` or `Atomic`). Previously async bindings silently never ran, so this was not a concern in practice.
- **Crystal >= 1.20.1 required** (previously >= 1.20.0).

### Added

- `app.async(name = "lune-task") { ... }` — runs a block on a dedicated OS thread (`Fiber::ExecutionContext::Isolated`). Use this for background timers, pollers, and any long-running work instead of `spawn`, which does not work in Lune apps (the native event loop owns the main thread permanently).
- `lune doctor` now validates that Crystal >= 1.20.1 is installed and reports the installed version with a clear error if it falls short.
- `make clean` target removes build artifacts for the lune binary and the example app.

### Changed

- `async: true` binding callbacks now run on a dedicated OS thread via `Fiber::ExecutionContext::Isolated` instead of a cooperative fiber. `sleep`, `Channel`, HTTP, and all blocking IO work correctly inside async bindings.
- `Bridge#dispatch_eval` (used by `app.emit`) now silently drops calls after the bridge is closed, preventing a crash when a background task emits after the window is closed.
- Production asset server (`AssetServer`) runs its HTTP accept loop on an `Isolated` thread and handles per-connection fibers on a `Parallel` pool, so embedded assets load correctly in production builds.
- Compilation flags `-Dpreview_mt -Dexecution_context` are now required and passed automatically by `lune dev`, `lune build`, and `make test`/`make build`/`make release`. Manual `crystal build` invocations must include both flags.
- Minimum Crystal version raised to `>= 1.20.1` (required for `Fiber::ExecutionContext`).
- Example app clock migrated from `spawn` to `app.async("clock")`.

### Fixed

- Async bindings on macOS/Linux were silently broken — spawned fibers never executed because the main thread was permanently blocked in the AppKit/GTK event loop. The fix uses real OS threads.
- Production builds showed a blank webview because the embedded asset HTTP server's connection-handling fibers could not be scheduled. Fixed by running the server on a `Parallel` execution context.

---

## [0.4.5] - 2026-05-16

### Added

- Bidirectional event bus — `app.on`, `app.once`, `app.off`, and `app.dispatch_event` on the Crystal side let the app listen for events emitted from JavaScript. `emit(name, data?)` in `runtime.js` / `runtime.d.ts` is the JS counterpart. Both sides share a single event-name namespace, making request/response and notification patterns straightforward.
- Example app (`demo/`) — a self-contained Vite + Crystal demo that exercises drag-and-drop, tray, clipboard, file dialogs, notifications, and the event bus, serving as both a reference and a manual smoke-test harness.

---

## [0.4.4] - 2026-05-16

### Changed

- Runner inline `wv.init` JavaScript extracted into a dedicated `Lune::Runtime::Scripts` module with private methods per concern (`keyboard_shortcuts`, `event_bus`, `drag_zone`, `file_drop`). No behaviour change — internal cleanup only.

### Fixed

- Traffic lights (close/minimize/zoom) were unresponsive when both `mac.full_size_content` and `enable_file_drop` (or `on_file_drop`) were active at the same time. With `NSWindowStyleMaskFullSizeContentView` the content view spans the titlebar, so the drop overlay's hit-test was claiming traffic-light clicks. The overlay now explicitly passes through clicks that land on any standard window button.

---

## [0.4.3] - 2026-05-16

### Added

- Default macOS menu bar — App, Edit, and Window menus are set up automatically so Lune apps feel like proper macOS citizens out of the box. The app name in the menu is taken from `opts.title`. No configuration required.
- `opts.mac` — macOS-specific window options grouped under a dedicated `MacOptions` struct, keeping them clearly separate from cross-platform settings.
- `opts.mac.full_size_content` — extends the content view to fill the entire window frame including the area behind the title bar, and makes the title bar itself transparent. The traffic lights remain visible.
- `opts.mac.transparent` — clears the window and WebView backgrounds so CSS `backdrop-filter` effects can sample whatever is behind the window, enabling frosted-glass / "mirror" style UIs.
- `opts.mac.hide_title` — hides the window title text while keeping the title bar and traffic lights visible. Commonly combined with `full_size_content` for a clean custom header.
- `opts.mac.appearance` — forces a specific appearance mode (`MacAppearance::Auto` / `Dark` / `Light`) regardless of the system setting.
- `opts.mac.content_protection` — prevents the window from appearing in screenshots, screen recordings, or screen sharing.
- `opts.mac.always_on_top` — keeps the window above all other windows, including those from other apps.
- `opts.drag_zone` / `opts.drag_value` — CSS custom property-based drag zones. Set `drag_zone` to a CSS property name (e.g. `"--lune-draggable"`) and any element with that property set to `drag_value` (default `"drag"`) becomes a window drag handle. Detection walks up the DOM tree so marking a container makes all its children draggable.
- `opts.disable_context_menu` — suppresses the browser's built-in right-click context menu across the entire window.
- `opts.enable_file_drop` — registers the window as a native drop target. The WebView's own drag handling is automatically suppressed so dropped files don't navigate the page.
- `opts.disable_webview_drop` — disables WebView drag handling without setting up a drop target, preventing accidental file opens without enabling the full drop API.
- `opts.drop_zone` / `opts.drop_value` — CSS custom property-based drop zones. Elements with the named property set to `drop_value` receive the `lune-drop-target-active` class while a file is held over them. Position tracking is driven natively so the class updates work even though the WebView's own dragover events are suppressed.
- `opts.on_file_drop` — Crystal callback fired on drop. Signature changed to `(Int32, Int32, Array(String)) -> Nil` — receives the drop position in logical pixels alongside the file paths. Setting this callback automatically enables file drop.
- `onFileDrop(cb)` / `onFileDropOff()` — JS runtime helpers for subscribing to file drops from the frontend. The event payload is `{ x, y, paths }`, consistent with the Crystal callback.

---

## [0.4.2] - 2026-05-15

### Added

- Window state persistence — window position and size are saved on close and restored on the next launch. State is stored at `~/Library/Application Support/<appname>/window.json` (macOS) or `~/.config/<appname>/window.json` (Linux), where `<appname>` is derived from the window title. Zero configuration required.
- App icon support — set `icon:` in `lune.yml` to bundle an icon into the `lune build` output. macOS accepts `.icns` or `.png` (auto-converted via `sips`/`iconutil`); Linux accepts `.png`.
- Extended file dialogs — `openDir(prompt)` for folder selection, `openFiles(prompt)` for multi-file selection, `messageInfo`, `messageWarning`, `messageError` for native alert dialogs, and `messageQuestion` for yes/no confirmation (returns `"Yes"` or `"No"`).

### Changed

- `generate_runtime_js` and `generate_runtime_dts` are now derived dynamically from `RuntimeBinding` instances instead of hardcoded heredoc strings. Each built-in binding carries its own arg names and optional `ts_return_type`, so the generated `runtime.js` and `runtime.d.ts` are always in sync with the registered bindings.
- Added `Lune::RuntimeBinding < Binding` subclass for runtime/internal bindings — overrides `to_js_stub` and `to_dts_sig` to emit `export function` / `export declare function` style output, and strips the `__lune.` prefix for JS function names.
- Added `App#register` to accept a pre-built `Binding` directly, bypassing `app.bind`.
- `TraySetMenuBinding < RuntimeBinding` handles the `JSON.stringify` call and `{ id, label }[]` TypeScript arg type for `traySetMenu`.
- The `@[Lune::Bind]` macro now extracts real Crystal parameter names and passes them into the generated `.d.ts` signatures. `greet(msg: string)` instead of `greet(arg0: string)`.

---

## [0.4.1] - 2026-05-15

### Changed

- All built-in capabilities (lifecycle, filesystem, clipboard, window controls, dialogs, tray, notifications, screen) are now implemented as `Lune::Installable` classes — the same interface used by user modules. `Bindings::Native.build` and `Bindings::Runtime.build` factory methods are gone.
- `app.bind` parameter renamed: `name:` → `method:` for consistency with `Lune::Binding`
- `Lune::BindingDef` renamed to `Lune::Binding`

---

## [0.4.0] - 2026-05-15

### Added

- Native platform features are now built into Lune — window controls, file dialogs, system tray, notifications, and screen info ship out of the box with no extra shard required
- macOS native bindings via ObjC (`NSWindow`, `NSOpenPanel`, `NSSavePanel`, `UNUserNotificationCenter`, `NSStatusBar`, `NSScreen`)
- Linux native bindings via GTK3/libnotify (`GtkWindow`, `GtkFileChooserDialog`, `GtkStatusIcon`, `libnotify`, `GdkMonitor`)
- `minimize()`, `maximize()`, `center()`, `setTitle(title)`, `setSize(width, height)` — native window controls from JS
- `openFile(prompt)`, `saveFile(prompt, defaultName)` — native file picker and save dialogs
- `trayShow(iconPath)`, `trayHide()`, `traySetIcon(path)`, `traySetMenu(items)` — system tray icon and context menu
- `notify(title, body)` — native OS notifications; macOS falls back to `osascript` for unbundled binaries
- `screenInfo()` — returns primary display width, height, and pixel scale factor
- `opts.on_tray_click` and `opts.on_menu_click` added to `Lune::Options` for wiring tray events from Crystal
- All native bindings auto-registered by `Runner` — no manual `on_window_ready` wiring required
- Native JS functions exported from `runtime.js`
- 45 new specs for native bindings, all passing via `lune_native_test_mock` compile flag
- `@app` injected into `Lune::Bindable` at install time — call `@app.emit` directly from any bound method without constructor arguments

## [0.3.6] - 2026-05-14

### Fixed

- Capability names corrected throughout — `readText`/`writeText` renamed to `clipboardRead`/`clipboardWrite` in ROADMAP, changelog, and specs
- Config spec and runtime bindings spec updated to use correct capability names
- Added spec for invalid capability names — unknown names are silently ignored, only real binding names are exposed

## [0.3.5] - 2026-05-14

### Added

- Clipboard bridge — `clipboardRead()` and `clipboardWrite(text)` available in JS via `runtime.js`; backed by `pbpaste`/`pbcopy` on macOS, `xclip` on Linux, PowerShell/`clip.exe` on Windows
- Capability allowlist — declare `capabilities:` in `lune.yml` to restrict which runtime bindings are exposed to JS; omit the key to allow all (default)
- Website version badge — nav bar now shows the current version linking to GitHub releases; `make patch`/`make minor` keep it in sync

### Fixed

- `bind_deferred` (`src/lune/webview.cr`) now wraps `LibWebView.bind` in `check_error` — a duplicate or failed binding name raises `Webview::Error` immediately rather than silently installing nothing and leaving the JS promise permanently pending
- `@@deferred_boxes << boxed` moved to after `check_error` — on a failed bind the GC-protection box is never stored, so it is collected instead of accumulating as an unreachable entry
- `on_load` and `on_navigate` user callbacks in `runner.cr` are now wrapped in `begin/rescue` before being passed into the webview's C bind callback — an exception from user code can no longer cross the C FFI boundary (undefined behaviour); failures are logged at `error` level with a `debug`-level stacktrace, matching the pattern in `bridge.cr`

## [0.3.4] - 2026-05-14

### Added

- `lune.yml` window defaults — declare `title`, `width`, `height`, `min_width`, `min_height`, `max_width`, `max_height`, `resizable`, `debug` under a `window:` key; values apply before the `Lune.run` opts block, which can still override any of them
- App paths bridge — `homeDir()`, `tempDir()`, `downloadsDir()`, `appDataDir()` available in JS via `runtime.js`; platform-aware (`appDataDir` returns `~/Library/Application Support` on macOS, `$XDG_DATA_HOME` on Linux, `%APPDATA%` on Windows)
- VitePress documentation site under `website/`; deployed to GitHub Pages via `.github/workflows/deploy-docs.yml`

### Changed

- `Lune::Config` now refers to project config loaded from `lune.yml`; logger config class renamed to `Lune::LogConfig`
- Runtime bindings consolidated — path functions merged into `Lune::Bindings::Runtime`; no separate path module

## [0.3.3] - 2026-05-14

### Added

- Dev error overlay — when `lune dev` compilation fails, a dedicated error window opens showing the Crystal compiler output. The window is owned by the CLI, stays open while you edit, and closes automatically when the next build succeeds.
- `lune init --force` (`-f`) — deletes the target directory and reinitializes from scratch.
- `lune init --skip-existing` (`-k`) — forwards `--skip-existing` to `crystal init` so the command succeeds when run inside an existing Crystal project, skipping any files that are already present.

## [0.3.0] - 2026-05-13

### Breaking changes

- `Lune.run` signature changed — `app` is now the first positional argument and the block yields `Lune::Options` for window configuration instead of `Lune::App` for binding setup. Bindings must be registered on `app` before calling `Lune.run`.
- `App#bind`, `App#bind_async`, `App#bind_typed`, and `App#namespace` removed. Use `Lune::Bindable` (annotation-driven) or `App#bind(name:, namespace:, args:, return_type:, async:)` directly.
- JS namespace is now the Crystal class name, not a manually declared string. Method names are camelcased: `greet` → `Greet`, `slow_echo` → `SlowEcho`.

### Added

- `Lune::Runner` — extracted webview lifecycle; enables programmatic navigation via `runner.start(html:)` or `runner.start(url:)`
- `Lune::Options` — window options as a first-class object (`title`, `width`, `height`, `min_*`, `max_*`, `resizable`, `debug`, `on_navigate`, `on_close`)
- `Lune::BindingDef` — typed binding descriptor carrying namespace, argument types, and return type
- `-Dbuild_mode` compile flag — Crystal app runs in a pre-pass to generate `App.js` / `App.d.ts` before frontend bundling, so typed exports are available in production builds
- `App.d.ts` now contains precise TypeScript signatures derived from Crystal method annotations, not just `Promise<unknown>` stubs

### Changed

- `Lune::Bindable` uses the Crystal class name as the JS namespace; nested namespaces follow `::` (`Math::Trig` → `api.Math.Trig`)
- `Lune::Runtime` generates structured namespaced JS and typed `.d.ts` from `BindingDef` arrays
- `Lune::Bindings::Runtime` returns `Array(BindingDef)` instead of registering directly on the bridge
- CLI commands reorganized under `LuneCLI::Commands` module; constants extracted to `constants.cr`
- `generate_bindings` moved inside `Build#run` so test doubles fully cover the build path

### Specs

- Reorganized under `spec/lune/` and `spec/lune_cli/` mirroring source layout
- 128 examples covering `App`, `Bridge`, `Runtime`, `RuntimeBindings`, `Runner`, and all CLI commands

## [0.2.4] - 2026-05-11

### Fixed

- `lune dev` now passes the configured `frontend.dir` to the compiled app via `LUNE_FRONTEND_DIR`, so `write_js` writes to the correct directory (e.g. `ui/lunejs/`) instead of the hardcoded `frontend/lunejs/`

### CI

- Release workflow — pushing a `v*` tag builds `lune-linux-x86_64`, `lune-darwin-arm64`, and `lune-darwin-x86_64` and attaches them to the GitHub release

### Internal

- Reorganize CLI internals

## [0.2.3] - 2026-05-11

### Fixed

- **Windows**: run the webview on a dedicated OS thread via `Fiber::ExecutionContext::Isolated` so Crystal's IO scheduler is not starved by the WebView2 C event loop (based on Crystal core team guidance)
- **Windows**: replace `LibC.flock` with cross-platform `flock_exclusive` — `flock(2)` is POSIX-only; the stdlib wrapper uses `LockFileEx` on Windows

### CI

- Windows runner downloads WebView2 SDK headers via NuGet before `shards install`
- Windows runs `--no-codegen` type-check; webview `.lib` linking is not supported in CI

## [0.2.2] - 2026-05-11

### Changed

- CLI is now fully config-driven via `lune.yml` — removed `--frontend-dir`, `--app-entry`, `--dev-cmd`, `--build-cmd`, and `--dev-url` flags from all commands
- Logger no longer duplicates Argy error output; timestamped logs only appear during runtime events (compilation, file watching, etc.)
- Doctor command hardened for config-driven operation

## [0.2.1] - 2026-05-10

### Added

- `lune.yml` project config for frontend toolchain — `app_entry`, `frontend.dir`, `frontend.install`, `frontend.build`, `frontend.dev.cmd`, `frontend.dev.url`

## [0.2.0] - 2026-04-XX

### Added

- Runtime JS API and TypeScript definitions generated from registered bindings
- Event bus — `app.emit()` pushes events from Crystal to the frontend
- `lune doctor` command — checks Crystal, Node, npm, shards, and frontend deps
- Single-instance lock for `lune dev` and `lune run`
- Command aliases (`d` for dev, `b` for build, `r` for run)

## [0.1.3] - 2026-04-XX

### Added

- Keyboard shortcuts injected via `wv.init` (copy/paste/undo/redo/select-all)

### Fixed

- Binding errors only show stack traces under `--debug`

## [0.1.2] - 2026-04-XX

### Fixed

- Pass `binding_names` to `Runtime.write_js` in dev mode

## [0.1.1] - 2026-04-XX

### Fixed

- Windows compatibility fixes

## [0.1.0] - 2026-04-XX

Initial release.
