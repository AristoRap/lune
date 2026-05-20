# Screen

> Query the primary screen's resolution and pixel density.

|                  |                         |
| ---------------- | ----------------------- |
| **Config key**   | `screen`                |
| **JS namespace** | `Screen`                |
| **Core**         | No                      |
| **Phases**       | Bindable                |
| **Hard deps**    | —                       |
| **Platforms**    | macOS · Linux · Windows |

---

## JavaScript API

```js
import { Screen } from "../lunejs/runtime/runtime.js";

const { width, height, scale } = await Screen.info();
console.log(`${width}×${height} @ ${scale}x`);
```

| Method   | Returns               |
| -------- | --------------------- |
| `info()` | `Promise<ScreenInfo>` |

### `ScreenInfo`

```ts
interface ScreenInfo {
  width: number; // physical pixels
  height: number; // physical pixels
  scale: number; // device pixel ratio (e.g. 2.0 on Retina)
}
```

---

## Disabling

```yaml
capabilities:
  exclude:
    - screen
```
