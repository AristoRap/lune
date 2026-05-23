# System

> Quit the app, open URLs in the default browser, query the runtime environment, and read primary-screen info.

|                  |                         |
| ---------------- | ----------------------- |
| **Config key**   | `system`                |
| **JS namespace** | `System`                |
| **Core**         | No                      |
| **Phases**       | Bindable                |
| **Hard deps**    | —                       |
| **Platforms**    | macOS · Linux · Windows |

---

## JavaScript API

```js
import { lune } from "../lunejs/runtime/runtime.js";

// Close the window and exit the app
await lune.System.quit();

// Open a URL in the default browser
await lune.System.openUrl("https://example.com");

// Query the runtime environment
const env = await lune.System.environment();
console.log(env.os, env.arch, env.devtools);
// "darwin", "arm64", false

// Query the primary screen's resolution and pixel density
const { width, height, scale } = await lune.System.screenInfo();
console.log(`${width}×${height} @ ${scale}x`);
```

| Method        | Signature       | Returns                    |
| ------------- | --------------- | -------------------------- |
| `quit`        | `quit()`        | `Promise<void>`            |
| `openUrl`     | `openUrl(url)`  | `Promise<void>`            |
| `environment` | `environment()` | `Promise<LuneEnvironment>` |
| `screenInfo`  | `screenInfo()`  | `Promise<ScreenInfo>`      |

### `LuneEnvironment`

```ts
interface LuneEnvironment {
  os: "darwin" | "linux" | "windows";
  arch: "arm64" | "x86_64";
  devtools: boolean;
}
```

### `ScreenInfo`

```ts
interface ScreenInfo {
  width: number; // physical pixels
  height: number; // physical pixels
  scale: number; // device pixel ratio (e.g. 2.0 on Retina)
}
```

---

## Crystal options

```crystal
Lune.run(app) do |opts|
  # Custom quit handler (default: terminate the process)
  # configured via System's internal on_quit callback — set via registry

  # openUrl uses `open` on macOS, `xdg-open` on Linux, and `cmd /c start` on Windows.
end
```

---

## Platform notes

- **macOS** — Verified. `screenInfo` reads `NSScreen.main`.
- **Linux** — Untested. `screenInfo` reads the X11 root window via Xlib.
- **Windows** — Verified. `screenInfo` via `GetSystemMetrics(SM_CX/CYSCREEN)` for size and `GetDpiForSystem` for the DPI scale factor (`dpi / 96.0`). Requires Windows 10 1607+ for the DPI API; older Windows reports `scale: 1.0`.

---

## Disabling

```yaml
plugins:
  disabled:
    - system
```

Disables the whole namespace, including `screenInfo`. There's no per-method disable knob — if you don't want to expose screen info, scope your frontend to not call it.
