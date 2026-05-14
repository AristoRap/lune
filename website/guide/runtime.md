# Runtime Functions

Lune exposes built-in JavaScript functions via `runtime.js`. These cover app lifecycle, system integration, and filesystem paths — all backed by Crystal, with no extra dependencies.

```js
import { quit, openURL, environment, homeDir, appDataDir, clipboardRead, clipboardWrite } from '../lunejs/runtime/runtime.js'
```

All functions return a `Promise`. TypeScript declarations are in `runtime.d.ts`.

---

## App lifecycle

### `quit()`

Terminates the app.

```js
await quit()
```

---

### `openURL(url)`

Opens a URL in the system default browser.

```js
await openURL('https://example.com')
```

---

## System info

### `environment()`

Returns information about the current runtime environment.

```js
const env = await environment()
// { os: "darwin", arch: "arm64", debug: false }
```

**Type:**

```ts
interface LuneEnvironment {
  os: "darwin" | "linux" | "windows"
  arch: string   // "arm64" | "x86_64"
  debug: boolean
}
```

---

## Filesystem paths

These functions return platform-appropriate directory paths. All return `Promise<string>`.

### `homeDir()`

The current user's home directory.

```js
const home = await homeDir()  // e.g. "/Users/alice"
```

### `appDataDir()`

The platform-standard directory for storing application data.

| Platform | Path |
|----------|------|
| macOS    | `~/Library/Application Support` |
| Linux    | `$XDG_DATA_HOME` or `~/.local/share` |
| Windows  | `%APPDATA%` |

```js
const dataDir = await appDataDir()
```

### `downloadsDir()`

The user's Downloads directory (`~/Downloads` on macOS and Linux).

```js
const dl = await downloadsDir()
```

### `tempDir()`

The system temporary directory.

```js
const tmp = await tempDir()
```

---

## Clipboard

### `clipboardRead()`

Returns the current clipboard text content.

```js
const text = await clipboardRead()
```

### `clipboardWrite(text)`

Writes a string to the clipboard.

```js
await clipboardWrite('copied!')
```

Platform commands used internally: `pbpaste`/`pbcopy` on macOS, `xclip` on Linux, PowerShell/`clip.exe` on Windows.

---

## Events

For pushing data from Crystal to the frontend, see the [Events](./events) guide (`on`, `once`, `off`).
