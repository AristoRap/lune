# System

> Quit the app, open URLs in the default browser, and query the runtime environment.

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
import { System } from "../lunejs/runtime/runtime.js";

// Close the window and exit the app
await System.quit();

// Open a URL in the default browser
await System.openUrl("https://example.com");

// Query the runtime environment
const env = await System.environment();
console.log(env.os, env.arch, env.devtools);
// "darwin", "arm64", false
```

| Method        | Signature       | Returns                    |
| ------------- | --------------- | -------------------------- |
| `quit`        | `quit()`        | `Promise<void>`            |
| `openUrl`     | `openUrl(url)`  | `Promise<void>`            |
| `environment` | `environment()` | `Promise<LuneEnvironment>` |

### `LuneEnvironment`

```ts
interface LuneEnvironment {
  os: "darwin" | "linux" | "windows";
  arch: "arm64" | "x86_64";
  devtools: boolean;
}
```

---

## Crystal options

```crystal
Lune.run(app) do |opts|
  # Custom quit handler (default: terminate the process)
  # configured via System's internal on_quit callback — set via registry

  # openUrl uses `open` on macOS, `xdg-open` on Linux
end
```

---

## Disabling

```yaml
capabilities:
  disabled:
    - system
```
