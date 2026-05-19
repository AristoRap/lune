# Clipboard

> Read and write the system clipboard — text, HTML, and images.

|                  |                                                     |
| ---------------- | --------------------------------------------------- |
| **Config key**   | `clipboard`                                         |
| **JS namespace** | `Clipboard`                                         |
| **Core**         | No                                                  |
| **Phases**       | Bindable                                            |
| **Hard deps**    | —                                                   |
| **Platforms**    | macOS · Linux · Windows (HTML/image: macOS · Linux) |

---

## JavaScript API

All methods return a `Promise`.

### Text

```js
import { Clipboard } from "../lunejs/runtime/runtime.js";

const text = await Clipboard.read();
await Clipboard.write("Hello from Lune");
```

### HTML

```js
const html = await Clipboard.readHtml();
await Clipboard.writeHtml("<b>bold</b>");
```

### Images

Images are exchanged as data URLs (`data:image/png;base64,...`):

```js
const dataUrl = await Clipboard.readImage();
await Clipboard.writeImage(dataUrl);
```

---

## Full API reference

| Method       | Signature             | Returns                      |
| ------------ | --------------------- | ---------------------------- |
| `read`       | `read()`              | `Promise<string>`            |
| `write`      | `write(text)`         | `Promise<void>`              |
| `readHtml`   | `readHtml()`          | `Promise<string>`            |
| `writeHtml`  | `writeHtml(html)`     | `Promise<void>`              |
| `readImage`  | `readImage()`         | `Promise<string>` — data URL |
| `writeImage` | `writeImage(dataUrl)` | `Promise<void>`              |

---

## Platform notes

Text read/write uses `pbpaste`/`pbcopy` on macOS, `xclip` on Linux, and `clip.exe`/`powershell` on Windows. HTML and image operations use native APIs and are not yet implemented on Windows.

---

## Disabling

```yaml
capabilities:
  exclude:
    - clipboard
```
