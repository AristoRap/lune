# Runtime Functions

Lune exposes built-in JavaScript functions via `runtime.js`. They are organised into **namespace objects** — one per capability group — exported from the runtime module.

```js
import { Lifecycle, Clipboard, Events } from "../lunejs/runtime/runtime.js";

await Lifecycle.Quit();
const text = await Clipboard.Read();
Events.on("myEvent", (data) => console.log(data));
```

All bridge methods return a `Promise`. TypeScript declarations are in `runtime.d.ts`. You can also import the `runtime` default export which bundles every namespace:

```js
import runtime from "../lunejs/runtime/runtime.js";
await runtime.Lifecycle.Quit();
```

---

## Quick reference

| Namespace           | Method               | Signature                         | Returns                    | macOS | Linux | Windows |
| ------------------- | -------------------- | --------------------------------- | -------------------------- | :---: | :---: | :-----: |
| `Lifecycle`         | `Quit`               | `Quit()`                          | `Promise<void>`            |   ✓   |   ✓   |    ✓    |
| `Lifecycle`         | `OpenUrl`            | `OpenUrl(url)`                    | `Promise<void>`            |   ✓   |   ✓   |    ✓    |
| `Lifecycle`         | `Environment`        | `Environment()`                   | `Promise<LuneEnvironment>` |   ✓   |   ✓   |    ✓    |
| `Filesystem`        | `HomeDir`            | `HomeDir()`                       | `Promise<string>`          |   ✓   |   ✓   |    ✓    |
| `Filesystem`        | `AppDataDir`         | `AppDataDir()`                    | `Promise<string>`          |   ✓   |   ✓   |    ✓    |
| `Filesystem`        | `DownloadsDir`       | `DownloadsDir()`                  | `Promise<string>`          |   ✓   |   ✓   |    ✓    |
| `Filesystem`        | `TempDir`            | `TempDir()`                       | `Promise<string>`          |   ✓   |   ✓   |    ✓    |
| `Clipboard`         | `Read`               | `Read()`                          | `Promise<string>`          |   ✓   |   ✓   |    ✓    |
| `Clipboard`         | `Write`              | `Write(text)`                     | `Promise<void>`            |   ✓   |   ✓   |    ✓    |
| `Clipboard`         | `ReadHtml`           | `ReadHtml()`                      | `Promise<string>`          |   ✓   |   ✓   |   tbd   |
| `Clipboard`         | `WriteHtml`          | `WriteHtml(html)`                 | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Clipboard`         | `ReadImage`          | `ReadImage()`                     | `Promise<string>`          |   ✓   |   ✓   |   tbd   |
| `Clipboard`         | `WriteImage`         | `WriteImage(dataUrl)`             | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Window`            | `Minimize`           | `Minimize()`                      | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Window`            | `Maximize`           | `Maximize()`                      | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Window`            | `Center`             | `Center()`                        | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Window`            | `SetTitle`           | `SetTitle(title)`                 | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Window`            | `SetSize`            | `SetSize(width, height)`          | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Dialogs`           | `OpenFile`           | `OpenFile(prompt)`                | `Promise<string>`          |   ✓   |   ✓   |   tbd   |
| `Dialogs`           | `OpenDir`            | `OpenDir(prompt)`                 | `Promise<string>`          |   ✓   |   ✓   |   tbd   |
| `Dialogs`           | `OpenFiles`          | `OpenFiles(prompt)`               | `Promise<string[]>`        |   ✓   |   ✓   |   tbd   |
| `Dialogs`           | `SaveFile`           | `SaveFile(prompt, filename)`      | `Promise<string>`          |   ✓   |   ✓   |   tbd   |
| `Dialogs`           | `MessageInfo`        | `MessageInfo(title, message)`     | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Dialogs`           | `MessageWarning`     | `MessageWarning(title, message)`  | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Dialogs`           | `MessageError`       | `MessageError(title, message)`    | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Dialogs`           | `MessageQuestion`    | `MessageQuestion(title, message)` | `Promise<string>`          |   ✓   |   ✓   |   tbd   |
| `Tray`              | `Show`               | `Show(iconPath)`                  | `Promise<void>`            |   ✓   |  ✓ ¹  |   tbd   |
| `Tray`              | `Hide`               | `Hide()`                          | `Promise<void>`            |   ✓   |  ✓ ¹  |   tbd   |
| `Tray`              | `SetIcon`            | `SetIcon(path)`                   | `Promise<void>`            |   ✓   |  ✓ ¹  |   tbd   |
| `Tray`              | `SetMenu`            | `SetMenu(items)`                  | `Promise<void>`            |   ✓   |  ✓ ¹  |   tbd   |
| `Notifications`     | `Notify`             | `Notify(title, body)`             | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Screen`            | `Info`               | `Info()`                          | `Promise<ScreenInfo>`      |   ✓   |   ✓   |   tbd   |
| `ContextMenuBridge` | `SetContextMenu` ²   | `SetContextMenu(items)`           | `void`                     |   ✓   |  tbd  |   tbd   |
| `ContextMenuBridge` | `ClearContextMenu` ² | `ClearContextMenu()`              | `void`                     |   ✓   |  tbd  |   tbd   |
| `ContextMenuBridge` | `OnContextMenu` ²    | `OnContextMenu(cb)`               | `void`                     |   ✓   |  tbd  |   tbd   |
| `DragOut`           | `Start` ²            | `Start(paths)`                    | `Promise<void>`            |   ✓   |  tbd  |   tbd   |
| `DeepLink`          | `OnDeepLink` ³       | `OnDeepLink(cb)`                  | `void`                     |   ✓   |   ✓   |   tbd   |
| `DeepLink`          | `OnDeepLinkOff` ³    | `OnDeepLinkOff()`                 | `void`                     |   ✓   |   ✓   |   tbd   |
| `Events`            | `On`                 | `On(name, cb)`                    | `void`                     |   ✓   |   ✓   |    ✓    |
| `Events`            | `Once`               | `Once(name, cb)`                  | `void`                     |   ✓   |   ✓   |    ✓    |
| `Events`            | `Off`                | `Off(name, cb?)`                  | `void`                     |   ✓   |   ✓   |    ✓    |
| `Events`            | `Emit`               | `Emit(name, data?)`               | `Promise<void>`            |   ✓   |   ✓   |    ✓    |
| `FileDrop`          | `OnFileDrop`         | `OnFileDrop(cb)`                  | `void`                     |   ✓   |   ✓   |   tbd   |
| `FileDrop`          | `OnFileDropOff`      | `OnFileDropOff()`                 | `void`                     |   ✓   |   ✓   |   tbd   |

¹ Requires XWayland on Wayland compositors.
² Requires both the `context_menu` and `context_menu_bridge` capabilities to be active.
³ Enable via [`url_schemes`](../configuration#url_schemes) in `lune.yml`.

> **Linux prerequisites:** GTK3 and libnotify headers are required for native features (window controls, tray, dialogs, notifications, screen).
>
> ```sh
> # Ubuntu / Debian
> sudo apt install libgtk-3-dev libnotify-dev
> # Fedora
> sudo dnf install gtk3-devel libnotify-devel
> ```

---

## Capabilities

`include`/`exclude` in `lune.yml` operate on whole **capabilities** — groups of related functions — referenced by their **capability name**, not by individual method names.

| Capability name        | JS namespace        | Methods included                                                                                                   |
| ---------------------- | ------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `lifecycle`            | `Lifecycle`         | `Quit`, `OpenUrl`, `Environment`                                                                                   |
| `filesystem`           | `Filesystem`        | `HomeDir`, `TempDir`, `DownloadsDir`, `AppDataDir`                                                                 |
| `clipboard`            | `Clipboard`         | `Read`, `Write`, `ReadHtml`, `WriteHtml`, `ReadImage`, `WriteImage`                                                |
| `window`               | `Window`            | `Minimize`, `Maximize`, `Center`, `SetTitle`, `SetSize`                                                            |
| `dialogs`              | `Dialogs`           | `OpenFile`, `OpenDir`, `OpenFiles`, `SaveFile`, `MessageInfo`, `MessageWarning`, `MessageError`, `MessageQuestion` |
| `tray`                 | `Tray`              | `Show`, `Hide`, `SetIcon`, `SetMenu`                                                                               |
| `notifications`        | `Notifications`     | `Notify`                                                                                                           |
| `screen`               | `Screen`            | `Info`                                                                                                             |
| `context_menu`         | `ContextMenu`       | Low-level bridge (`Show`) — not called directly; use `context_menu_bridge`                                         |
| `context_menu_bridge`  | `ContextMenuBridge` | `SetContextMenu`, `ClearContextMenu`, `OnContextMenu` (core — requires `context_menu`)                             |
| `drag_out`             | `DragOut`           | `Start`                                                                                                            |
| `deep_link`            | `DeepLink`          | `OnDeepLink`, `OnDeepLinkOff` (event-only, no bridge binding)                                                      |
| `event_bus`            | `Events`            | `On`, `Once`, `Off`, `Emit` (core — no bridge binding)                                                             |
| `keyboard_shortcuts`   | —                   | Cmd/Ctrl+C/V/Z/etc. JS injection (core — no bridge binding)                                                        |
| `file_drop`            | `FileDrop`          | `OnFileDrop`, `OnFileDropOff` (core — controlled by `opts.drop`)                                                   |
| `disable_context_menu` | —                   | Suppresses browser right-click menu (core — controlled by `opts.disable_context_menu`)                             |
| `drag_zone`            | —                   | Window-drag-by-CSS injection (core — controlled by `opts.drag.zone`)                                               |
| `navigation`           | —                   | SPA navigation tracking (core — controlled by `opts.on_navigate`)                                                  |

`include: [lifecycle]` exposes all three `Lifecycle` methods. Individual method names are not valid capability names — they log a warning and are ignored.

See [Configuration → capabilities](../configuration#capabilities) for the full syntax.

---

## App lifecycle

### `Lifecycle.Quit()`

Terminates the app.

```js
import { Lifecycle } from "../lunejs/runtime/runtime.js";

await Lifecycle.Quit();
```

---

### `Lifecycle.OpenUrl(url)`

Opens a URL in the system default browser.

```js
await Lifecycle.OpenUrl("https://example.com");
```

---

## System info

### `Lifecycle.Environment()`

Returns information about the current runtime environment.

```js
const env = await Lifecycle.Environment();
// { os: "darwin", arch: "arm64", debug: false }
```

**Type:**

```ts
interface LuneEnvironment {
  os: "darwin" | "linux" | "windows";
  arch: string; // "arm64" | "x86_64"
  debug: boolean;
}
```

---

## Filesystem paths

These methods return platform-appropriate directory paths. All return `Promise<string>`.

```js
import { Filesystem } from "../lunejs/runtime/runtime.js";
```

### `Filesystem.HomeDir()`

The current user's home directory.

```js
const home = await Filesystem.HomeDir(); // e.g. "/Users/alice"
```

### `Filesystem.AppDataDir()`

The platform-standard directory for storing application data.

| Platform | Path                                 |
| -------- | ------------------------------------ |
| macOS    | `~/Library/Application Support`      |
| Linux    | `$XDG_DATA_HOME` or `~/.local/share` |
| Windows  | `%APPDATA%`                          |

```js
const dataDir = await Filesystem.AppDataDir();
```

### `Filesystem.DownloadsDir()`

The user's Downloads directory (`~/Downloads` on macOS and Linux).

```js
const dl = await Filesystem.DownloadsDir();
```

### `Filesystem.TempDir()`

The system temporary directory.

```js
const tmp = await Filesystem.TempDir();
```

---

## Clipboard

```js
import { Clipboard } from "../lunejs/runtime/runtime.js";
```

### `Clipboard.Read()`

Returns the current clipboard text content.

```js
const text = await Clipboard.Read();
```

Platform commands: `pbpaste`/`pbcopy` on macOS, `xclip` on Linux, PowerShell/`clip.exe` on Windows.

### `Clipboard.Write(text)`

Writes a plain-text string to the clipboard.

```js
await Clipboard.Write("copied!");
```

### `Clipboard.ReadHtml()`

Returns the HTML content from the clipboard, or `""` if none is present.

```js
const html = await Clipboard.ReadHtml();
// e.g. "<b>Hello</b>"
```

**Supported:** macOS (NSPasteboard), Linux (xclip) — **Planned:** Windows

### `Clipboard.WriteHtml(html)`

Writes an HTML string to the clipboard.

```js
await Clipboard.WriteHtml("<b>Hello</b> from <em>Lune</em>");
```

**Supported:** macOS, Linux — **Planned:** Windows

### `Clipboard.ReadImage()`

Returns a PNG image from the clipboard as a `data:image/png;base64,…` string, or `""` if no image is present. TIFF images on macOS are automatically converted to PNG.

```js
const dataUrl = await Clipboard.ReadImage();
if (dataUrl) {
  document.querySelector("img").src = dataUrl;
}
```

**Supported:** macOS (NSPasteboard), Linux (xclip) — **Planned:** Windows

### `Clipboard.WriteImage(dataUrl)`

Writes a PNG image to the clipboard from a `data:image/png;base64,…` data URL.

```js
await Clipboard.WriteImage(dataUrl);
```

**Supported:** macOS, Linux — **Planned:** Windows

---

## Window controls

**Supported:** macOS, Linux — **Planned:** Windows

```js
import { Window } from "../lunejs/runtime/runtime.js";
```

### `Window.Minimize()`

Minimizes the window.

```js
await Window.Minimize();
```

### `Window.Maximize()`

Expands the window to fill the screen.

```js
await Window.Maximize();
```

### `Window.Center()`

Centers the window on the primary display.

```js
await Window.Center();
```

### `Window.SetTitle(title)`

Updates the window title bar text.

```js
await Window.SetTitle("My App");
```

### `Window.SetSize(width, height)`

Resizes the window in logical pixels.

```js
await Window.SetSize(1280, 800);
```

---

## File dialogs

**Supported:** macOS, Linux — **Planned:** Windows

```js
import { Dialogs } from "../lunejs/runtime/runtime.js";
```

### `Dialogs.OpenFile(prompt)`

Shows a native open-file dialog. Returns the selected path, or `""` if cancelled.

```js
const path = await Dialogs.OpenFile("Select an image");
// "/Users/alice/Pictures/photo.jpg"  or  ""
```

### `Dialogs.OpenDir(prompt)`

Shows a native folder picker. Returns the selected directory path, or `""` if cancelled.

```js
const dir = await Dialogs.OpenDir("Choose a folder");
// "/Users/alice/Documents"  or  ""
```

### `Dialogs.OpenFiles(prompt)`

Shows a native open-files dialog that allows selecting multiple files. Returns an array of paths (empty array if cancelled).

```js
const paths = await Dialogs.OpenFiles("Select images");
// ["/Users/alice/a.jpg", "/Users/alice/b.jpg"]  or  []
```

### `Dialogs.SaveFile(prompt, filename)`

Shows a native save dialog. Returns the chosen path, or `""` if cancelled.

```js
const dest = await Dialogs.SaveFile("Export as", "report.csv");
// "/Users/alice/Desktop/report.csv"  or  ""
```

### `Dialogs.MessageInfo(title, message)`

Shows an informational message dialog.

```js
await Dialogs.MessageInfo("Done", "Your file has been saved.");
```

### `Dialogs.MessageWarning(title, message)`

Shows a warning message dialog.

```js
await Dialogs.MessageWarning(
  "Low disk space",
  "You are running low on storage.",
);
```

### `Dialogs.MessageError(title, message)`

Shows an error message dialog.

```js
await Dialogs.MessageError(
  "Export failed",
  "Could not write to the selected path.",
);
```

### `Dialogs.MessageQuestion(title, message)`

Shows a yes/no confirmation dialog. Returns `"Yes"` or `"No"`.

```js
const answer = await Dialogs.MessageQuestion("Confirm", "Delete this file?");
if (answer === "Yes") {
  // proceed
}
```

---

## System tray

**Supported:** macOS, Linux (XWayland required on Wayland) — **Planned:** Windows

```js
import { Tray } from "../lunejs/runtime/runtime.js";
```

### `Tray.Show(iconPath)`

Shows the tray icon. Pass `""` for the default ● icon, or a file path for a custom image (18×18 px recommended).

```js
await Tray.Show(""); // default icon
await Tray.Show("/path/to/icon.png");
```

### `Tray.Hide()`

Hides the tray icon.

```js
await Tray.Hide();
```

### `Tray.SetIcon(path)`

Swaps the icon without hiding or showing it.

```js
await Tray.SetIcon("/path/to/new.png");
```

### `Tray.SetMenu(items)`

Attaches a context menu to the tray icon. Pass an empty array to clear the menu. Use `"---"` as the `id` for a separator.

```js
await Tray.SetMenu([
  { id: "open", label: "Open" },
  { id: "---", label: "" },
  { id: "quit", label: "Quit" },
]);
```

**Type:**

```ts
interface TrayMenuItem {
  id: string;
  label: string;
}
```

### Tray callbacks

Wire click/menu events in Crystal via `opts`:

```crystal
Lune.run(app, assets: "frontend/dist") do |opts|
  opts.tray do |t|
    t.on_click      = -> { app.emit("trayClick", nil) }
    t.on_menu_click = ->(id : String) { app.emit("trayMenuClick", id) }
  end
end
```

```js
import { Events, Lifecycle } from "../lunejs/runtime/runtime.js";

Events.on("trayClick", () => console.log("icon clicked"));
Events.on("trayMenuClick", (id) => {
  if (id === "quit") Lifecycle.Quit();
});
```

> Attaching a non-empty menu replaces the direct click handler — `trayClick` will not fire while menu items are present. Calling `Tray.SetMenu([])` clears the menu and restores direct click behaviour.

---

## Notifications

**Supported:** macOS, Linux — **Planned:** Windows

### `Notifications.Notify(title, body)`

Sends a native OS notification.

```js
import { Notifications } from "../lunejs/runtime/runtime.js";

await Notifications.Notify("Build complete", "Your app compiled successfully.");
```

> **macOS:** uses `UNUserNotificationCenter` for apps signed with a Developer certificate (Team Identifier present). Unsigned and ad-hoc-signed builds (including `lune dev`) fall back to `osascript`. To enable `UNUserNotificationCenter` in production, set [`mac.sign`](../configuration.md#macsign) in `lune.yml`.
> **Linux:** uses `libnotify`.

---

## Screen

**Supported:** macOS, Linux — **Planned:** Windows

### `Screen.Info()`

Returns the primary display dimensions and pixel density.

```js
import { Screen } from "../lunejs/runtime/runtime.js";

const screen = await Screen.Info();
// { width: 2560, height: 1440, scale: 2 }
```

**Type:**

```ts
interface ScreenInfo {
  width: number; // logical width in points
  height: number; // logical height in points
  scale: number; // pixel ratio (1 = standard, 2 = Retina / HiDPI)
}
```

---

## Context menus

**Supported:** macOS — **Planned:** Linux, Windows

Show a native right-click context menu driven entirely from JavaScript. Requires both `context_menu` and `context_menu_bridge` capabilities to be active (both are on by default).

```js
import { ContextMenuBridge } from "../lunejs/runtime/runtime.js";
```

### `ContextMenuBridge.SetContextMenu(items)`

Registers items to display whenever the user right-clicks anywhere in the window. Replaces any previously set menu.

```js
ContextMenuBridge.SetContextMenu([
  { id: "copy", label: "Copy" },
  { id: "paste", label: "Paste" },
  { separator: true },
  { id: "delete", label: "Delete", enabled: false },
]);

ContextMenuBridge.OnContextMenu((id) => {
  console.log("selected:", id);
});
```

**Type:**

```ts
interface ContextMenuItem {
  id?: string;
  label?: string;
  enabled?: boolean;
  separator?: boolean;
}
```

### `ContextMenuBridge.ClearContextMenu()`

Removes the registered menu. Right-clicks revert to default browser behaviour (or are suppressed if `disable_context_menu` is set).

```js
ContextMenuBridge.ClearContextMenu();
```

### `ContextMenuBridge.OnContextMenu(cb)`

Subscribes to context menu item selections. The callback receives the `id` of the selected item. Not called if the menu is dismissed without a selection.

```js
ContextMenuBridge.OnContextMenu((id) => {
  if (id === "delete") deleteSelectedItem();
});
```

---

## Drag-out

**Supported:** macOS — **Planned:** Linux, Windows

Initiate a native drag session that hands local files from the app to the OS. The user can then drop them into Finder, another app, or anywhere else that accepts files.

### `DragOut.Start(paths)`

Starts a native drag with the given array of absolute file paths. Call it from a `pointerdown` or `mousedown` handler — the drag uses the current mouse position automatically.

| Parameter | Type       | Description                          |
| --------- | ---------- | ------------------------------------ |
| `paths`   | `string[]` | Absolute paths to the files to drag. |

```js
import { DragOut } from "../lunejs/runtime/runtime.js";

element.addEventListener("pointerdown", () => {
  DragOut.Start(["/path/to/file.txt"]);
});
```

---

## Deep links

**Supported:** macOS (built app), Linux — **Planned:** Windows

Receive URLs routed to your app by the OS when the user opens a custom URL scheme link (e.g. `myapp://...`). Common use case: OAuth redirect flows.

First declare the schemes in `lune.yml`:

```yaml
url_schemes:
  - myapp
```

Then subscribe in JavaScript:

```js
import { DeepLink } from "../lunejs/runtime/runtime.js";
```

### `DeepLink.OnDeepLink(cb)`

Registers a callback that fires whenever the OS routes a URL with your registered scheme to the running app.

```js
DeepLink.OnDeepLink((url) => {
  console.log("Received:", url);
  // e.g. "myapp://oauth/callback?code=abc123"
});
```

### `DeepLink.OnDeepLinkOff()`

Removes the deep link listener registered by `DeepLink.OnDeepLink`.

```js
DeepLink.OnDeepLinkOff();
```

> **macOS:** The scheme is registered via `CFBundleURLTypes` in `Info.plist` at build time. Deep links received during `lune dev` will not be routed by the OS (the binary is not a `.app` bundle). Use `window.__lune.crystalEmit("deep_link", { url: "..." })` to simulate them during development.
>
> **Linux:** Each deep link opens a new process. Lune emits the URL from `ARGV` before the window becomes visible. Single-instance forwarding (so the URL lands in an already-running window) is planned but not yet implemented.

See the [Deep Links guide](./deep-links) for a full walkthrough.

---

## Events

The event bus is bidirectional. Crystal emits to JS with `app.emit(name, data)` and JS emits to Crystal via `Events.Emit`.

```js
import { Events } from "../lunejs/runtime/runtime.js";
```

### `Events.on(name, cb)`

Subscribes to an event by name. The callback fires every time the event is emitted (from either side). `cb` receives the event payload.

```js
Events.on("myEvent", (data) => console.log(data));
```

### `Events.once(name, cb)`

Like `Events.on` but fires only for the next occurrence, then removes itself.

```js
Events.once("ready", () => init());
```

### `Events.off(name, cb?)`

Removes a listener. If `cb` is omitted, removes all listeners for `name`.

```js
Events.off("myEvent", handler);
Events.off("myEvent"); // removes all listeners for "myEvent"
```

### `Events.emit(name, data?)`

Emits an event from JavaScript to Crystal. The Crystal app receives it via `app.on(name) { |data| ... }`.

```js
await Events.emit("userAction", { kind: "save" });
```

See the [Events guide](./events) for the Crystal-side API and full examples.

---

## File drop

Enable native file drop via `opts.drop` in Crystal. See [Configuration → `drop`](../configuration#drop).

```js
import { FileDrop } from "../lunejs/runtime/runtime.js";
```

### `FileDrop.OnFileDrop(cb)`

Registers a callback that fires when files are dropped onto the window (or onto a configured drop zone). Receives the drop position and an array of absolute file paths.

```js
FileDrop.OnFileDrop((x, y, paths) => {
  console.log("dropped at", x, y, paths);
});
```

### `FileDrop.OnFileDropOff()`

Removes the file drop listener.

```js
FileDrop.OnFileDropOff();
```
