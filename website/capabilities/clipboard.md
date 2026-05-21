# Clipboard

> Read and write the system clipboard — text, HTML, and images.

|                  |                                                     |
| ---------------- | --------------------------------------------------- |
| **Config key**   | `clipboard`                                         |
| **JS namespace** | `Clipboard`                                         |
| **Core**         | No                                                  |
| **Phases**       | Bindable                                            |
| **Hard deps**    | —                                                   |
| **Platforms**    | macOS · Linux · Windows (image: macOS · Linux only) |

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

Text read/write uses `pbpaste`/`pbcopy` on macOS, `xclip` on Linux, and direct Win32 (`OpenClipboard` + `SetClipboardData(CF_UNICODETEXT)` / `GetClipboardData`) on Windows. HTML reads/writes use native APIs on all three. Image reads/writes work on macOS + Linux; on Windows they reject the returned `Promise` with `LuneError("UNAVAILABLE_ON_PLATFORM", …)` so cross-platform code can `.catch` and fall back. PNG ↔ CF_DIB conversion isn't implemented yet — tracked in [ROADMAP.md](https://github.com/AristoRap/lune/blob/main/ROADMAP.md).

---

## Disabling

```yaml
capabilities:
  disabled:
    - clipboard
```
