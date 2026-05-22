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
import { lune } from "../lunejs/runtime/runtime.js";

const text = await lune.Clipboard.read();
await lune.Clipboard.write("Hello from Lune");
```

### HTML

```js
const html = await lune.Clipboard.readHtml();
await lune.Clipboard.writeHtml("<b>bold</b>");
```

### Images

Images are exchanged as data URLs (`data:image/png;base64,...`):

```js
const dataUrl = await lune.Clipboard.readImage();
await lune.Clipboard.writeImage(dataUrl);
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

- **macOS** — Verified. Text via `pbpaste`/`pbcopy`; HTML and image via native APIs.
- **Linux** — Untested. Text via `xclip`; HTML and image via native APIs.
- **Windows** — Verified (text + HTML); image Not implemented. Text/HTML go through Win32 `CF_UNICODETEXT` / `CF_HTML`. Image needs PNG ↔ `CF_DIB` conversion — tracked in [ROADMAP.md](https://github.com/AristoRap/lune/blob/main/ROADMAP.md).

---

## Disabling

```yaml
plugins:
  disabled:
    - clipboard
```
