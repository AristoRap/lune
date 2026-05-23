# System

> Quit the app, open URLs in the default browser, query the runtime environment, read primary-screen info, and post native notifications.

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

// Post a native desktop notification
await lune.System.notify("Build complete", "Your app compiled successfully.");
```

| Method        | Signature             | Returns                                                                              |
| ------------- | --------------------- | ------------------------------------------------------------------------------------ |
| `quit`        | `quit()`              | `Promise<void>`                                                                      |
| `openUrl`     | `openUrl(url)`        | `Promise<void>`                                                                      |
| `environment` | `environment()`       | `Promise<{ os: "darwin" \| "linux" \| "windows"; arch: string; devtools: boolean }>` |
| `screenInfo`  | `screenInfo()`        | `Promise<{ width: number; height: number; scale: number }>`                          |
| `notify`      | `notify(title, body)` | `Promise<void>`                                                                      |

Return types are inlined structurally — `runtime.d.ts` no longer ships named `LuneEnvironment` / `ScreenInfo` interfaces. If you need a name, alias the inferred return type at the call site:

```ts
type LuneEnvironment = Awaited<ReturnType<typeof lune.System.environment>>;
type ScreenInfo = Awaited<ReturnType<typeof lune.System.screenInfo>>;
```

`screenInfo` fields are physical pixels (`width`, `height`) and the device pixel ratio (`scale` — e.g. `2.0` on Retina). `environment.arch` is `"arm64"` on aarch64, `"x86_64"` elsewhere.

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

## Notifications

`lune.System.notify(title, body)` posts a native OS desktop notification. Click handling (firing an event back into the app when the user clicks a notification) is not currently wired up.

- **macOS** — `NSUserNotificationCenter`. The app must be running; there is no persistence.
- **Linux** — `libnotify`. Requires `libnotify-dev` at build time.
- **Windows** — PowerShell + WinRT (`Windows.UI.Notifications` + `Windows.Data.Xml.Dom`). The AUMID is derived from `lune.yml`'s `name:` (sanitized to ASCII alphanumerics + `.`, clamped to 50 chars; `"Lune"` fallback) and auto-registered at `HKCU\Software\Classes\AppUserModelId\<AUMID>` on first call so toasts surface and persist in Action Center.

---

## Platform notes

- **macOS** — Verified. `screenInfo` reads `NSScreen.main`; `notify` via `NSUserNotificationCenter`.
- **Linux** — Untested. `screenInfo` reads the X11 root window via Xlib; `notify` via `libnotify`.
- **Windows** — Verified. `screenInfo` via `GetSystemMetrics(SM_CX/CYSCREEN)` for size and `GetDpiForSystem` for the DPI scale factor (`dpi / 96.0`). Requires Windows 10 1607+ for the DPI API; older Windows reports `scale: 1.0`. `notify` uses the PowerShell + WinRT toast path described above.

---

## Disabling

```yaml
plugins:
  disabled:
    - system
```

Disables the whole namespace, including `screenInfo` and `notify`. There's no per-method disable knob — if you only want to expose a subset, scope your frontend to call only the methods you want.
