# Runtime Functions

Lune exposes built-in JavaScript functions via `runtime.js`, organised into **namespace objects** — one per plugin. Import the namespaces you need:

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

For the full method list, signatures, and per-platform behaviour, see [Plugins](../plugins/) — each namespace has its own page with its complete JS API.

> **Linux prerequisites:** GTK3 and libnotify headers are required for native features (window controls, tray, dialogs, notifications, screen).
>
> ```sh
> # Ubuntu / Debian
> sudo apt install libgtk-3-dev libnotify-dev
> # Fedora
> sudo dnf install gtk3-devel libnotify-devel
> ```
