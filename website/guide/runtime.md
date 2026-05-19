# Runtime Functions

Lune exposes built-in JavaScript functions via `runtime.js`, organised into **namespace objects** — one per capability. Import the namespaces you need:

```js
import { System, Clipboard, Events } from "../lunejs/runtime/runtime.js";

await System.quit();
const text = await Clipboard.read();
Events.on("myEvent", (data) => console.log(data));
```

All bridge methods return a `Promise`. TypeScript declarations are in `runtime.d.ts`. You can also import the default export which bundles every namespace:

```js
import runtime from "../lunejs/runtime/runtime.js";
await runtime.System.quit();
```

---

## Quick reference

| Namespace       | Method            | Signature                         | Returns                         | Docs                                           |
| --------------- | ----------------- | --------------------------------- | ------------------------------- | ---------------------------------------------- |
| `System`        | `quit`            | `quit()`                          | `Promise<void>`                 | [System](../capabilities/system)               |
| `System`        | `openUrl`         | `openUrl(url)`                    | `Promise<void>`                 | [System](../capabilities/system)               |
| `System`        | `environment`     | `environment()`                   | `Promise<LuneEnvironment>`      | [System](../capabilities/system)               |
| `Filesystem`    | `homeDir`         | `homeDir()`                       | `Promise<string>`               | [Filesystem](../capabilities/filesystem)       |
| `Filesystem`    | `appDataDir`      | `appDataDir()`                    | `Promise<string>`               | [Filesystem](../capabilities/filesystem)       |
| `Filesystem`    | `downloadsDir`    | `downloadsDir()`                  | `Promise<string>`               | [Filesystem](../capabilities/filesystem)       |
| `Filesystem`    | `tempDir`         | `tempDir()`                       | `Promise<string>`               | [Filesystem](../capabilities/filesystem)       |
| `Clipboard`     | `read`            | `read()`                          | `Promise<string>`               | [Clipboard](../capabilities/clipboard)         |
| `Clipboard`     | `write`           | `write(text)`                     | `Promise<void>`                 | [Clipboard](../capabilities/clipboard)         |
| `Clipboard`     | `readHtml`        | `readHtml()`                      | `Promise<string>`               | [Clipboard](../capabilities/clipboard)         |
| `Clipboard`     | `writeHtml`       | `writeHtml(html)`                 | `Promise<void>`                 | [Clipboard](../capabilities/clipboard)         |
| `Clipboard`     | `readImage`       | `readImage()`                     | `Promise<string>`               | [Clipboard](../capabilities/clipboard)         |
| `Clipboard`     | `writeImage`      | `writeImage(dataUrl)`             | `Promise<void>`                 | [Clipboard](../capabilities/clipboard)         |
| `Window`        | `minimize`        | `minimize()`                      | `Promise<void>`                 | [Window](../capabilities/window)               |
| `Window`        | `maximize`        | `maximize()`                      | `Promise<void>`                 | [Window](../capabilities/window)               |
| `Window`        | `center`          | `center()`                        | `Promise<void>`                 | [Window](../capabilities/window)               |
| `Window`        | `setTitle`        | `setTitle(title)`                 | `Promise<void>`                 | [Window](../capabilities/window)               |
| `Window`        | `setSize`         | `setSize(width, height)`          | `Promise<void>`                 | [Window](../capabilities/window)               |
| `Dialogs`       | `openFile`        | `openFile(prompt)`                | `Promise<string>`               | [Dialogs](../capabilities/dialogs)             |
| `Dialogs`       | `openDir`         | `openDir(prompt)`                 | `Promise<string>`               | [Dialogs](../capabilities/dialogs)             |
| `Dialogs`       | `openFiles`       | `openFiles(prompt)`               | `Promise<string[]>`             | [Dialogs](../capabilities/dialogs)             |
| `Dialogs`       | `saveFile`        | `saveFile(prompt, filename)`      | `Promise<string>`               | [Dialogs](../capabilities/dialogs)             |
| `Dialogs`       | `messageInfo`     | `messageInfo(title, message)`     | `Promise<void>`                 | [Dialogs](../capabilities/dialogs)             |
| `Dialogs`       | `messageWarning`  | `messageWarning(title, message)`  | `Promise<void>`                 | [Dialogs](../capabilities/dialogs)             |
| `Dialogs`       | `messageError`    | `messageError(title, message)`    | `Promise<void>`                 | [Dialogs](../capabilities/dialogs)             |
| `Dialogs`       | `messageQuestion` | `messageQuestion(title, message)` | `Promise<string>`               | [Dialogs](../capabilities/dialogs)             |
| `Tray`          | `show`            | `show(iconPath)`                  | `Promise<void>`                 | [Tray](../capabilities/tray)                   |
| `Tray`          | `hide`            | `hide()`                          | `Promise<void>`                 | [Tray](../capabilities/tray)                   |
| `Tray`          | `setIcon`         | `setIcon(path)`                   | `Promise<void>`                 | [Tray](../capabilities/tray)                   |
| `Tray`          | `setMenu`         | `setMenu(items)`                  | `Promise<void>`                 | [Tray](../capabilities/tray)                   |
| `Notifications` | `notify`          | `notify(title, body)`             | `Promise<void>`                 | [Notifications](../capabilities/notifications) |
| `Screen`        | `info`            | `info()`                          | `Promise<ScreenInfo>`           | [Screen](../capabilities/screen)               |
| `ContextMenu`   | `set`             | `set(items)`                      | `void`                          | [ContextMenu](../capabilities/context-menu)    |
| `ContextMenu`   | `clear`           | `clear()`                         | `void`                          | [ContextMenu](../capabilities/context-menu)    |
| `ContextMenu`   | `onSelect`        | `onSelect(cb)`                    | `void`                          | [ContextMenu](../capabilities/context-menu)    |
| `DragOut`       | `start`           | `start(paths)`                    | `Promise<void>`                 | [DragOut](../capabilities/drag-out)            |
| `DeepLink`      | `on`              | `on(cb)`                          | `void`                          | [DeepLink](../capabilities/deep-link)          |
| `DeepLink`      | `off`             | `off()`                           | `void`                          | [DeepLink](../capabilities/deep-link)          |
| `Events`        | `on`              | `on(name, cb)`                    | `void`                          | [EventBus](../capabilities/event-bus)          |
| `Events`        | `once`            | `once(name, cb)`                  | `void`                          | [EventBus](../capabilities/event-bus)          |
| `Events`        | `off`             | `off(name, cb?)`                  | `void`                          | [EventBus](../capabilities/event-bus)          |
| `Events`        | `emit`            | `emit(name, data?)`               | `Promise<void>`                 | [EventBus](../capabilities/event-bus)          |
| `FileDrop`      | `on`              | `on(cb)`                          | `void`                          | [FileDrop](../capabilities/file-drop)          |
| `FileDrop`      | `off`             | `off()`                           | `void`                          | [FileDrop](../capabilities/file-drop)          |
| `FileWatch`     | `watch`           | `watch(path)`                     | `Promise<void>`                 | [FileWatch](../capabilities/file-watch)        |
| `FileWatch`     | `unwatch`         | `unwatch(path)`                   | `Promise<void>`                 | [FileWatch](../capabilities/file-watch)        |
| `FileWatch`     | `on`              | `on(cb)`                          | `void`                          | [FileWatch](../capabilities/file-watch)        |
| `FileWatch`     | `off`             | `off(cb?)`                        | `void`                          | [FileWatch](../capabilities/file-watch)        |
| `Shell`         | `spawn`           | `spawn(command, args)`            | `Promise<string>`               | [Shell](../capabilities/shell)                 |
| `Shell`         | `run`             | `run(command, args?)`             | `Promise<{stdout,stderr,code}>` | [Shell](../capabilities/shell)                 |
| `Shell`         | `kill`            | `kill(pid)`                       | `Promise<void>`                 | [Shell](../capabilities/shell)                 |
| `Shell`         | `listen`          | `listen(pid, opts)`               | `void`                          | [Shell](../capabilities/shell)                 |
| `Shell`         | `unlisten`        | `unlisten(pid)`                   | `void`                          | [Shell](../capabilities/shell)                 |
| `Stream`        | `on`              | `on(name, cb)`                    | `void`                          | [Stream](../capabilities/stream)               |
| `Stream`        | `once`            | `once(name, cb)`                  | `void`                          | [Stream](../capabilities/stream)               |
| `Stream`        | `off`             | `off(name, cb?)`                  | `void`                          | [Stream](../capabilities/stream)               |
| `Stream`        | `send`            | `send(name, data?)`               | `void`                          | [Stream](../capabilities/stream)               |

> **Linux prerequisites:** GTK3 and libnotify headers are required for native features (window controls, tray, dialogs, notifications, screen).
>
> ```sh
> # Ubuntu / Debian
> sudo apt install libgtk-3-dev libnotify-dev
> # Fedora
> sudo dnf install gtk3-devel libnotify-devel
> ```
