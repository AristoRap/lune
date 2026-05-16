# Runtime Functions

Lune exposes built-in JavaScript functions via `runtime.js`. These cover app lifecycle, system integration, filesystem paths, native window controls, file dialogs, system tray, notifications, and screen info — all backed by Crystal.

```js
import {
  quit,
  minimize,
  notify,
  screenInfo,
} from "../lunejs/runtime/runtime.js";
```

All functions return a `Promise`. TypeScript declarations are in `runtime.d.ts`.

## Quick reference

| Function          | Signature                         | Returns                    | macOS | Linux | Windows |
| ----------------- | --------------------------------- | -------------------------- | :---: | :---: | :-----: |
| `quit`            | `quit()`                          | `Promise<void>`            |   ✓   |   ✓   |    ✓    |
| `openURL`         | `openURL(url)`                    | `Promise<void>`            |   ✓   |   ✓   |    ✓    |
| `environment`     | `environment()`                   | `Promise<LuneEnvironment>` |   ✓   |   ✓   |    ✓    |
| `homeDir`         | `homeDir()`                       | `Promise<string>`          |   ✓   |   ✓   |    ✓    |
| `appDataDir`      | `appDataDir()`                    | `Promise<string>`          |   ✓   |   ✓   |    ✓    |
| `downloadsDir`    | `downloadsDir()`                  | `Promise<string>`          |   ✓   |   ✓   |    ✓    |
| `tempDir`         | `tempDir()`                       | `Promise<string>`          |   ✓   |   ✓   |    ✓    |
| `clipboardRead`   | `clipboardRead()`                 | `Promise<string>`          |   ✓   |   ✓   |    ✓    |
| `clipboardWrite`  | `clipboardWrite(text)`            | `Promise<void>`            |   ✓   |   ✓   |    ✓    |
| `minimize`        | `minimize()`                      | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `maximize`        | `maximize()`                      | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `center`          | `center()`                        | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `setTitle`        | `setTitle(title)`                 | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `setSize`         | `setSize(width, height)`          | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `openFile`        | `openFile(prompt)`                | `Promise<string>`          |   ✓   |   ✓   |   tbd   |
| `openDir`         | `openDir(prompt)`                 | `Promise<string>`          |   ✓   |   ✓   |   tbd   |
| `openFiles`       | `openFiles(prompt)`               | `Promise<string[]>`        |   ✓   |   ✓   |   tbd   |
| `saveFile`        | `saveFile(prompt, filename)`      | `Promise<string>`          |   ✓   |   ✓   |   tbd   |
| `messageInfo`     | `messageInfo(title, message)`     | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `messageWarning`  | `messageWarning(title, message)`  | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `messageError`    | `messageError(title, message)`    | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `messageQuestion` | `messageQuestion(title, message)` | `Promise<string>`          |   ✓   |   ✓   |   tbd   |
| `trayShow`        | `trayShow(iconPath)`              | `Promise<void>`            |   ✓   |  ✓ ¹  |   tbd   |
| `trayHide`        | `trayHide()`                      | `Promise<void>`            |   ✓   |  ✓ ¹  |   tbd   |
| `traySetIcon`     | `traySetIcon(path)`               | `Promise<void>`            |   ✓   |  ✓ ¹  |   tbd   |
| `traySetMenu`     | `traySetMenu(items)`              | `Promise<void>`            |   ✓   |  ✓ ¹  |   tbd   |
| `notify`          | `notify(title, body)`             | `Promise<void>`            |   ✓   |   ✓   |   tbd   |
| `screenInfo`      | `screenInfo()`                    | `Promise<ScreenInfo>`      |   ✓   |   ✓   |   tbd   |

¹ Requires XWayland on Wayland compositors.

> **Linux prerequisites:** GTK3 and libnotify headers are required for native features (window controls, tray, dialogs, notifications, screen).
>
> ```sh
> # Ubuntu / Debian
> sudo apt install libgtk-3-dev libnotify-dev
> # Fedora
> sudo dnf install gtk3-devel libnotify-devel
> ```

---

## App lifecycle

### `quit()`

Terminates the app.

```js
await quit();
```

---

### `openURL(url)`

Opens a URL in the system default browser.

```js
await openURL("https://example.com");
```

---

## System info

### `environment()`

Returns information about the current runtime environment.

```js
const env = await environment();
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

These functions return platform-appropriate directory paths. All return `Promise<string>`.

### `homeDir()`

The current user's home directory.

```js
const home = await homeDir(); // e.g. "/Users/alice"
```

### `appDataDir()`

The platform-standard directory for storing application data.

| Platform | Path                                 |
| -------- | ------------------------------------ |
| macOS    | `~/Library/Application Support`      |
| Linux    | `$XDG_DATA_HOME` or `~/.local/share` |
| Windows  | `%APPDATA%`                          |

```js
const dataDir = await appDataDir();
```

### `downloadsDir()`

The user's Downloads directory (`~/Downloads` on macOS and Linux).

```js
const dl = await downloadsDir();
```

### `tempDir()`

The system temporary directory.

```js
const tmp = await tempDir();
```

---

## Clipboard

### `clipboardRead()`

Returns the current clipboard text content.

```js
const text = await clipboardRead();
```

### `clipboardWrite(text)`

Writes a string to the clipboard.

```js
await clipboardWrite("copied!");
```

Platform commands used internally: `pbpaste`/`pbcopy` on macOS, `xclip` on Linux, PowerShell/`clip.exe` on Windows.

---

## Window controls

**Supported:** macOS, Linux — **Planned:** Windows

Control the native window at runtime from JavaScript.

### `minimize()`

Minimizes the window.

```js
await minimize();
```

### `maximize()`

Expands the window to fill the screen.

```js
await maximize();
```

### `center()`

Centers the window on the primary display.

```js
await center();
```

### `setTitle(title)`

Updates the window title bar text.

```js
await setTitle("My App");
```

### `setSize(width, height)`

Resizes the window in logical pixels.

```js
await setSize(1280, 800);
```

---

## File dialogs

**Supported:** macOS, Linux — **Planned:** Windows

Open native file picker and save dialogs.

### `openFile(prompt)`

Shows a native open-file dialog. Returns the selected path, or `""` if cancelled.

```js
const path = await openFile("Select an image");
// "/Users/alice/Pictures/photo.jpg"  or  ""
```

### `openDir(prompt)`

Shows a native folder picker. Returns the selected directory path, or `""` if cancelled.

```js
const dir = await openDir("Choose a folder");
// "/Users/alice/Documents"  or  ""
```

### `openFiles(prompt)`

Shows a native open-files dialog that allows selecting multiple files. Returns an array of paths (empty array if cancelled).

```js
const paths = await openFiles("Select images");
// ["/Users/alice/a.jpg", "/Users/alice/b.jpg"]  or  []
```

### `saveFile(prompt, filename)`

Shows a native save dialog. Returns the chosen path, or `""` if cancelled.

```js
const dest = await saveFile("Export as", "report.csv");
// "/Users/alice/Desktop/report.csv"  or  ""
```

### `messageInfo(title, message)`

Shows an informational message dialog.

```js
await messageInfo("Done", "Your file has been saved.");
```

### `messageWarning(title, message)`

Shows a warning message dialog.

```js
await messageWarning("Low disk space", "You are running low on storage.");
```

### `messageError(title, message)`

Shows an error message dialog.

```js
await messageError("Export failed", "Could not write to the selected path.");
```

### `messageQuestion(title, message)`

Shows a yes/no confirmation dialog. Returns `"Yes"` or `"No"`.

```js
const answer = await messageQuestion("Confirm", "Delete this file?");
if (answer === "Yes") {
  // proceed
}
```

---

## System tray

**Supported:** macOS, Linux (XWayland required on Wayland) — **Planned:** Windows

Show a status-bar icon with an optional click callback or context menu.

### `trayShow(iconPath)`

Shows the tray icon. Pass `""` for the default ● icon, or a file path for a custom image (18×18 px recommended).

```js
await trayShow(""); // default icon
await trayShow("/path/to/icon.png");
```

### `trayHide()`

Hides the tray icon.

```js
await trayHide();
```

### `traySetIcon(path)`

Swaps the icon without hiding or showing it.

```js
await traySetIcon("/path/to/new.png");
```

### `traySetMenu(items)`

Attaches a context menu to the tray icon. Use `"---"` as the `id` for a separator.

```js
await traySetMenu([
  { id: "open", label: "Open" },
  { id: "---", label: "" },
  { id: "quit", label: "Quit" },
]);
```

### Tray callbacks

Wire click/menu events in Crystal via `opts`:

```crystal
Lune.run(app, assets: "frontend/dist") do |opts|
  opts.on_tray_click = -> { app.emit("trayClick", nil) }
  opts.on_menu_click = ->(id : String) { app.emit("trayMenuClick", id) }
end
```

```js
import { on } from "../lunejs/runtime/runtime.js";

on("trayClick", () => console.log("icon clicked"));
on("trayMenuClick", (id) => {
  if (id === "quit") quit();
});
```

> Attaching a menu replaces the direct click handler — `trayClick` will not fire when a menu is active.

---

## Notifications

**Supported:** macOS, Linux — **Planned:** Windows

### `notify(title, body)`

Sends a native OS notification.

```js
await notify("Build complete", "Your app compiled successfully.");
```

> **macOS:** uses `UNUserNotificationCenter`. Non-bundled binaries fall back to `osascript`.
> **Linux:** uses `libnotify`.

---

## Screen

**Supported:** macOS, Linux — **Planned:** Windows

### `screenInfo()`

Returns the primary display dimensions and pixel density.

```js
const screen = await screenInfo();
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

## Events

The event bus is bidirectional. See the [Events](./events) guide for `on`, `once`, `off`, and `emit` — both Crystal→JS and JS→Crystal directions.
