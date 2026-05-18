# Runtime Functions

Lune exposes built-in JavaScript functions via `runtime.js`. They are organised into **namespace objects** — one per capability group — exported from the runtime module.

```js
import { System, Clipboard, Events } from "../lunejs/runtime/runtime.js";

await System.quit();
const text = await Clipboard.read();
Events.on("myEvent", (data) => console.log(data));
```

All bridge methods return a `Promise`. TypeScript declarations are in `runtime.d.ts`. You can also import the `runtime` default export which bundles every namespace:

```js
import runtime from "../lunejs/runtime/runtime.js";
await runtime.System.quit();
```

---

## Quick reference

| Namespace       | Method            | Signature                         | Returns                    | macOS | Linux | Windows |
| --------------- | ----------------- | --------------------------------- | -------------------------- | :---: | :---: | :-----: |
| `System`     | `quit`            | `quit()`                          | `Promise<void>`            |   ✓   |   ✓   |    ✓    |
| `System`     | `openUrl`         | `openUrl(url)`                    | `Promise<void>`            |   ✓   |   ✓   |    ✓    |
| `System`     | `environment`     | `environment()`                   | `Promise<LuneEnvironment>` |   ✓   |   ✓   |    ✓    |
| `Filesystem`    | `homeDir`         | `homeDir()`                       | `Promise<string>`          |   ✓   |   ✓   |    ✓    |
| `Filesystem`    | `appDataDir`      | `appDataDir()`                    | `Promise<string>`          |   ✓   |   ✓   |    ✓    |
| `Filesystem`    | `downloadsDir`    | `downloadsDir()`                  | `Promise<string>`          |   ✓   |   ✓   |    ✓    |
| `Filesystem`    | `tempDir`         | `tempDir()`                       | `Promise<string>`          |   ✓   |   ✓   |    ✓    |
| `Clipboard`     | `read`            | `read()`                          | `Promise<string>`          |   ✓   |   ✓   |    ✓    |
| `Clipboard`     | `write`           | `write(text)`                     | `Promise<void>`            |   ✓   |   ✓   |    ✓    |
| `Clipboard`     | `readHtml`        | `readHtml()`                      | `Promise<string>`          |   ✓   |   ✓   |   tbd   |
| `Clipboard`     | `writeHtml`       | `writeHtml(html)`                 | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Clipboard`     | `readImage`       | `readImage()`                     | `Promise<string>`          |   ✓   |   ✓   |   tbd   |
| `Clipboard`     | `writeImage`      | `writeImage(dataUrl)`             | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Window`        | `minimize`        | `minimize()`                      | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Window`        | `maximize`        | `maximize()`                      | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Window`        | `center`          | `center()`                        | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Window`        | `setTitle`        | `setTitle(title)`                 | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Window`        | `setSize`         | `setSize(width, height)`          | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Dialogs`       | `openFile`        | `openFile(prompt)`                | `Promise<string>`          |   ✓   |   ✓   |   tbd   |
| `Dialogs`       | `openDir`         | `openDir(prompt)`                 | `Promise<string>`          |   ✓   |   ✓   |   tbd   |
| `Dialogs`       | `openFiles`       | `openFiles(prompt)`               | `Promise<string[]>`        |   ✓   |   ✓   |   tbd   |
| `Dialogs`       | `saveFile`        | `saveFile(prompt, filename)`      | `Promise<string>`          |   ✓   |   ✓   |   tbd   |
| `Dialogs`       | `messageInfo`     | `messageInfo(title, message)`     | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Dialogs`       | `messageWarning`  | `messageWarning(title, message)`  | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Dialogs`       | `messageError`    | `messageError(title, message)`    | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Dialogs`       | `messageQuestion` | `messageQuestion(title, message)` | `Promise<string>`          |   ✓   |   ✓   |   tbd   |
| `Tray`          | `show`            | `show(iconPath)`                  | `Promise<void>`            |   ✓   |  ✓ ¹  |   tbd   |
| `Tray`          | `hide`            | `hide()`                          | `Promise<void>`            |   ✓   |  ✓ ¹  |   tbd   |
| `Tray`          | `setIcon`         | `setIcon(path)`                   | `Promise<void>`            |   ✓   |  ✓ ¹  |   tbd   |
| `Tray`          | `setMenu`         | `setMenu(items)`                  | `Promise<void>`            |   ✓   |  ✓ ¹  |   tbd   |
| `Notifications` | `notify`          | `notify(title, body)`             | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `Screen`        | `info`            | `info()`                          | `Promise<ScreenInfo>`      |   ✓   |   ✓   |   tbd   |
| `ContextMenu`   | `set` ²           | `set(items)`                      | `void`                     |   ✓   |  tbd  |   tbd   |
| `ContextMenu`   | `clear` ²         | `clear()`                         | `void`                     |   ✓   |  tbd  |   tbd   |
| `ContextMenu`   | `onSelect` ²      | `onSelect(cb)`                    | `void`                     |   ✓   |  tbd  |   tbd   |
| `DragOut`       | `start` ²         | `start(paths)`                    | `Promise<void>`            |   ✓   |  tbd  |   tbd   |
| `DeepLink`      | `onDeepLink` ³    | `onDeepLink(cb)`                  | `void`                     |   ✓   |   ✓   |   tbd   |
| `DeepLink`      | `onDeepLinkOff` ³ | `onDeepLinkOff()`                 | `void`                     |   ✓   |   ✓   |   tbd   |
| `Events`        | `on`              | `on(name, cb)`                    | `void`                     |   ✓   |   ✓   |    ✓    |
| `Events`        | `once`            | `once(name, cb)`                  | `void`                     |   ✓   |   ✓   |    ✓    |
| `Events`        | `off`             | `off(name, cb?)`                  | `void`                     |   ✓   |   ✓   |    ✓    |
| `Events`        | `emit`            | `emit(name, data?)`               | `Promise<void>`            |   ✓   |   ✓   |    ✓    |
| `FileDrop`      | `on`              | `on(cb)`                          | `void`                     |   ✓   |   ✓   |   tbd   |
| `FileDrop`      | `off`             | `off()`                           | `void`                     |   ✓   |   ✓   |   tbd   |

¹ Requires XWayland on Wayland compositors.
² Requires the `context_menu` capability to be active.
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

| Capability name        | JS namespace    | Methods included                                                                                                   |
| ---------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------ |
| `system`               | `System`        | `quit`, `openUrl`, `environment`                                                                                   |
| `filesystem`           | `Filesystem`    | `homeDir`, `tempDir`, `downloadsDir`, `appDataDir`                                                                 |
| `clipboard`            | `Clipboard`     | `read`, `write`, `readHtml`, `writeHtml`, `readImage`, `writeImage`                                                |
| `window`               | `Window`        | `minimize`, `maximize`, `center`, `setTitle`, `setSize`                                                            |
| `dialogs`              | `Dialogs`       | `openFile`, `openDir`, `openFiles`, `saveFile`, `messageInfo`, `messageWarning`, `messageError`, `messageQuestion` |
| `tray`                 | `Tray`          | `show`, `hide`, `setIcon`, `setMenu`                                                                               |
| `notifications`        | `Notifications` | `notify`                                                                                                           |
| `screen`               | `Screen`        | `info`                                                                                                             |
| `context_menu`         | `ContextMenu`   | `set`, `clear`, `onSelect`                                                                                         |
| `drag_out`             | `DragOut`       | `start`                                                                                                            |
| `deep_link`            | `DeepLink`      | `onDeepLink`, `onDeepLinkOff` (event-only, no bridge binding)                                                      |
| `event_bus`            | `Events`        | `on`, `once`, `off`, `emit` (core — no bridge binding)                                                             |
| `keyboard_shortcuts`   | —               | Cmd/Ctrl+C/V/Z/etc. JS injection (core — no bridge binding)                                                        |
| `file_drop`            | `FileDrop`      | `on`, `off` (core — controlled by `opts.drop`)                                                                     |

`include: [system]` exposes all three `System` methods. Individual method names are not valid capability names — they log a warning and are ignored.

See [Configuration → capabilities](../configuration#capabilities) for the full syntax.

---

## System

### `System.quit()`

Terminates the app.

```js
import { System } from "../lunejs/runtime/runtime.js";

await System.quit();
```

---

### `System.openUrl(url)`

Opens a URL in the system default browser.

```js
await System.openUrl("https://example.com");
```

---

## System info

### `System.environment()`

Returns information about the current runtime environment.

```js
const env = await System.environment();
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

### `Filesystem.homeDir()`

The current user's home directory.

```js
const home = await Filesystem.homeDir(); // e.g. "/Users/alice"
```

### `Filesystem.appDataDir()`

The platform-standard directory for storing application data.

| Platform | Path                                 |
| -------- | ------------------------------------ |
| macOS    | `~/Library/Application Support`      |
| Linux    | `$XDG_DATA_HOME` or `~/.local/share` |
| Windows  | `%APPDATA%`                          |

```js
const dataDir = await Filesystem.appDataDir();
```

### `Filesystem.downloadsDir()`

The user's Downloads directory (`~/Downloads` on macOS and Linux).

```js
const dl = await Filesystem.downloadsDir();
```

### `Filesystem.tempDir()`

The system temporary directory.

```js
const tmp = await Filesystem.tempDir();
```

---

## Clipboard

```js
import { Clipboard } from "../lunejs/runtime/runtime.js";
```

### `Clipboard.read()`

Returns the current clipboard text content.

```js
const text = await Clipboard.read();
```

Platform commands: `pbpaste`/`pbcopy` on macOS, `xclip` on Linux, PowerShell/`clip.exe` on Windows.

### `Clipboard.write(text)`

Writes a plain-text string to the clipboard.

```js
await Clipboard.write("copied!");
```

### `Clipboard.readHtml()`

Returns the HTML content from the clipboard, or `""` if none is present.

```js
const html = await Clipboard.readHtml();
// e.g. "<b>Hello</b>"
```

**Supported:** macOS (NSPasteboard), Linux (xclip) — **Planned:** Windows

### `Clipboard.writeHtml(html)`

Writes an HTML string to the clipboard.

```js
await Clipboard.writeHtml("<b>Hello</b> from <em>Lune</em>");
```

**Supported:** macOS, Linux — **Planned:** Windows

### `Clipboard.readImage()`

Returns a PNG image from the clipboard as a `data:image/png;base64,…` string, or `""` if no image is present. TIFF images on macOS are automatically converted to PNG.

```js
const dataUrl = await Clipboard.readImage();
if (dataUrl) {
  document.querySelector("img").src = dataUrl;
}
```

**Supported:** macOS (NSPasteboard), Linux (xclip) — **Planned:** Windows

### `Clipboard.writeImage(dataUrl)`

Writes a PNG image to the clipboard from a `data:image/png;base64,…` data URL.

```js
await Clipboard.writeImage(dataUrl);
```

**Supported:** macOS, Linux — **Planned:** Windows

---

## Window controls

**Supported:** macOS, Linux — **Planned:** Windows

```js
import { Window } from "../lunejs/runtime/runtime.js";
```

### `Window.minimize()`

Minimizes the window.

```js
await Window.minimize();
```

### `Window.maximize()`

Expands the window to fill the screen.

```js
await Window.maximize();
```

### `Window.center()`

Centers the window on the primary display.

```js
await Window.center();
```

### `Window.setTitle(title)`

Updates the window title bar text.

```js
await Window.setTitle("My App");
```

### `Window.setSize(width, height)`

Resizes the window in logical pixels.

```js
await Window.setSize(1280, 800);
```

---

## File dialogs

**Supported:** macOS, Linux — **Planned:** Windows

```js
import { Dialogs } from "../lunejs/runtime/runtime.js";
```

### `Dialogs.openFile(prompt)`

Shows a native open-file dialog. Returns the selected path, or `""` if cancelled.

```js
const path = await Dialogs.openFile("Select an image");
// "/Users/alice/Pictures/photo.jpg"  or  ""
```

### `Dialogs.openDir(prompt)`

Shows a native folder picker. Returns the selected directory path, or `""` if cancelled.

```js
const dir = await Dialogs.openDir("Choose a folder");
// "/Users/alice/Documents"  or  ""
```

### `Dialogs.openFiles(prompt)`

Shows a native open-files dialog that allows selecting multiple files. Returns an array of paths (empty array if cancelled).

```js
const paths = await Dialogs.openFiles("Select images");
// ["/Users/alice/a.jpg", "/Users/alice/b.jpg"]  or  []
```

### `Dialogs.saveFile(prompt, filename)`

Shows a native save dialog. Returns the chosen path, or `""` if cancelled.

```js
const dest = await Dialogs.saveFile("Export as", "report.csv");
// "/Users/alice/Desktop/report.csv"  or  ""
```

### `Dialogs.messageInfo(title, message)`

Shows an informational message dialog.

```js
await Dialogs.messageInfo("Done", "Your file has been saved.");
```

### `Dialogs.messageWarning(title, message)`

Shows a warning message dialog.

```js
await Dialogs.messageWarning(
  "Low disk space",
  "You are running low on storage.",
);
```

### `Dialogs.messageError(title, message)`

Shows an error message dialog.

```js
await Dialogs.messageError(
  "Export failed",
  "Could not write to the selected path.",
);
```

### `Dialogs.messageQuestion(title, message)`

Shows a yes/no confirmation dialog. Returns `"Yes"` or `"No"`.

```js
const answer = await Dialogs.messageQuestion("Confirm", "Delete this file?");
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

### `Tray.show(iconPath)`

Shows the tray icon. Pass `""` for the default ● icon, or a file path for a custom image (18×18 px recommended).

```js
await Tray.show(""); // default icon
await Tray.show("/path/to/icon.png");
```

### `Tray.hide()`

Hides the tray icon.

```js
await Tray.hide();
```

### `Tray.setIcon(path)`

Swaps the icon without hiding or showing it.

```js
await Tray.setIcon("/path/to/new.png");
```

### `Tray.setMenu(items)`

Attaches a context menu to the tray icon. Pass an empty array to clear the menu. Use `"---"` as the `id` for a separator.

```js
await Tray.setMenu([
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

### Tray events

Tray activity is emitted automatically on the event bus — no configuration required. The default event name is `"trayEvent"`. Icon clicks carry the payload `"click"`; menu item selections carry the item `id`.

```js
import { Events, System } from "../lunejs/runtime/runtime.js";

Events.on("trayEvent", (payload) => {
  if (payload === "click") console.log("icon clicked");
  else if (payload === "quit") System.quit();
  else console.log("menu item:", payload);
});
```

Override the event name or use fully custom Crystal callbacks in `opts.tray`:

```crystal
# custom event name
opts.tray do |t|
  t.event = "myTray"
end

# full Crystal-side override
opts.tray do |t|
  t.on_click      = -> { puts "clicked" }
  t.on_menu_click = ->(id : String) { puts id }
end
```

> Attaching a non-empty menu replaces the direct click handler — `"click"` will not fire while menu items are present. Calling `Tray.setMenu([])` clears the menu and restores direct click behaviour.

---

## Notifications

**Supported:** macOS, Linux — **Planned:** Windows

### `Notifications.notify(title, body)`

Sends a native OS notification.

```js
import { Notifications } from "../lunejs/runtime/runtime.js";

await Notifications.notify("Build complete", "Your app compiled successfully.");
```

> **macOS:** uses `UNUserNotificationCenter` for apps signed with a Developer certificate (Team Identifier present). Unsigned and ad-hoc-signed builds (including `lune dev`) fall back to `osascript`. To enable `UNUserNotificationCenter` in production, set [`mac.sign`](../configuration.md#macsign) in `lune.yml`.
> **Linux:** uses `libnotify`.

---

## Screen

**Supported:** macOS, Linux — **Planned:** Windows

### `Screen.info()`

Returns the primary display dimensions and pixel density.

```js
import { Screen } from "../lunejs/runtime/runtime.js";

const screen = await Screen.info();
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

Show a native right-click context menu driven entirely from JavaScript. Requires the `context_menu` capability (on by default).

```js
import { ContextMenu } from "../lunejs/runtime/runtime.js";
```

### `ContextMenu.set(items)`

Registers items to display whenever the user right-clicks anywhere in the window. Replaces any previously set menu.

```js
ContextMenu.set([
  { id: "copy", label: "Copy" },
  { id: "paste", label: "Paste" },
  { separator: true },
  { id: "delete", label: "Delete", enabled: false },
]);

ContextMenu.onSelect((id) => {
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

### `ContextMenu.clear()`

Removes the registered menu. Right-clicks revert to default browser behaviour (or are suppressed if `disable_context_menu` is set).

```js
ContextMenu.clear();
```

### `ContextMenu.onSelect(cb)`

Subscribes to context menu item selections. The callback receives the `id` of the selected item. Not called if the menu is dismissed without a selection.

```js
ContextMenu.onSelect((id) => {
  if (id === "delete") deleteSelectedItem();
});
```

---

## Drag-out

**Supported:** macOS — **Planned:** Linux, Windows

Initiate a native drag session that hands local files from the app to the OS. The user can then drop them into Finder, another app, or anywhere else that accepts files.

### `DragOut.start(paths)`

Starts a native drag with the given array of absolute file paths. Call it from a `pointerdown` or `mousedown` handler — the drag uses the current mouse position automatically.

| Parameter | Type       | Description                          |
| --------- | ---------- | ------------------------------------ |
| `paths`   | `string[]` | Absolute paths to the files to drag. |

```js
import { DragOut } from "../lunejs/runtime/runtime.js";

element.addEventListener("pointerdown", () => {
  DragOut.start(["/path/to/file.txt"]);
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

### `DeepLink.onDeepLink(cb)`

Registers a callback that fires whenever the OS routes a URL with your registered scheme to the running app.

```js
DeepLink.onDeepLink((url) => {
  console.log("Received:", url);
  // e.g. "myapp://oauth/callback?code=abc123"
});
```

### `DeepLink.onDeepLinkOff()`

Removes the deep link listener registered by `DeepLink.onDeepLink`.

```js
DeepLink.onDeepLinkOff();
```

> **macOS:** The scheme is registered via `CFBundleURLTypes` in `Info.plist` at build time. Deep links received during `lune dev` will not be routed by the OS (the binary is not a `.app` bundle). Use `window.__lune.crystalEmit("deep_link", { url: "..." })` to simulate them during development.
>
> **Linux:** Each deep link opens a new process. Lune emits the URL from `ARGV` before the window becomes visible. Single-instance forwarding (so the URL lands in an already-running window) is planned but not yet implemented.

See the [Deep Links guide](./deep-links) for a full walkthrough.

---

## Events

The event bus is bidirectional. Crystal emits to JS with `app.emit(name, data)` and JS emits to Crystal via `Events.emit`.

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

### `FileDrop.on(cb)`

Registers a callback that fires when files are dropped onto the window (or onto a configured drop zone). Receives the drop position and an array of absolute file paths.

```js
FileDrop.on((x, y, paths) => {
  console.log("dropped at", x, y, paths);
});
```

### `FileDrop.off()`

Removes the file drop listener.

```js
FileDrop.off();
```
