# Changelog

## [0.8.0] - 2026-05-19

### Added

- **`Stream` capability** — bidirectional, ordered, low-latency WebSocket IPC stream. Use `app.stream_send(name, data)` from Crystal and `Stream.on` / `Stream.send` from JavaScript for high-frequency or continuous data flows (tickers, log tails, LLM token output) where the event bus's per-call `evaluateJavaScript` overhead would become a bottleneck. Auto-reconnects on disconnect; excludable via `lune.yml`.
- **`file_watch` capability** — monitor files and directories for filesystem changes. Call `FileWatch.watch(path)` / `FileWatch.unwatch(path)` from JavaScript; subscribe to change events with `FileWatch.on(cb)`. Events carry `{path, kind}` where `kind` is `"modified"`, `"created"`, `"deleted"`, or `"renamed"`. Backed by kqueue (`EVFILT_VNODE`) on macOS and inotify on Linux — no polling, no extra system dependencies. Hard-depends on `event_bus`; automatically disabled with a warning if `event_bus` is excluded.
- **`opts.file_watch.debounce`** — configurable debounce window (default 50 ms) that collapses the burst of raw OS events produced by a single editor save into one logical event per path. Set to `0.milliseconds` to receive raw events.

### Fixed

- **macOS 26+ crash on app close** — `deplete_run_loop_event_queue` in the webview destructor called `nextEventMatchingMask:` from a non-main OS thread. macOS 26 (Tahoe) began enforcing main-thread-only for that call; the resulting ObjC exception propagated as `std::terminate` → `SIGABRT`. Fixed upstream in `naqvis/webview` (`fff6c392`); the fix is now pulled in directly without a local patch.
- **File-drop JSON parse error swallowed** — the native drop callbacks now wrap the entire parse + dispatch in a typed `rescue JSON::ParseException | TypeCastError | KeyError`, preventing a hard crash if the ObjC layer sends unexpected data.
- **Linux inotify buffer overread** — the inotify event loop now validates `buf.size >= sizeof(InotifyEvent)` and `step <= buf.size` before advancing the pointer; a short read or an oversized `ev.len` could previously walk past the buffer end.
- **Darwin kevent fd leak on registration failure** — `FileWatch.add_watch` now registers the kevent before storing the fd in the watch map, and closes the fd if `kevent()` returns an error. Previously a failed registration left the fd recorded but unwatched (silent no-op).
- **Tray `setMenu` crash on malformed input** — the `set_menu` bridge callback now uses safe JSON navigation and wraps the parse in a typed rescue; a missing `id`/`label` key or invalid JSON previously caused a hard `TypeCastError` crash.
- **File-drop callback crash on unexpected JSON** — the native drop callbacks on both macOS and Linux now use `?.try(&.as_i?)`/`?.try(&.as_s?)` with safe defaults; malformed JSON from the native layer previously raised `TypeCastError`.
- **Bridge TOCTOU race in `dispatch_result`** — the closed guard is now checked both before queuing the dispatch *and* inside the queued block, closing the window where the webview could be torn down between the pre-dispatch check and block execution.
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
