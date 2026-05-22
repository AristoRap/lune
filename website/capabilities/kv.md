# KV

> Persistent key-value store for preferences and app config.

|                  |                      |
| ---------------- | -------------------- |
| **Config key**   | `kv`                 |
| **JS namespace** | `Kv`                 |
| **Core**         | No                   |
| **Phases**       | Bindable · Lifecycle |
| **Hard deps**    | —                    |
| **Platforms**    | all                  |

KV gives you a simple JSON-backed key-value store scoped to your app. Values persist across app restarts and are stored in the platform-standard app data directory. Use it for user preferences, last-used state, and lightweight config — anything that doesn't need the full query power of SQLite.

---

## Enabling

```yaml
capabilities:
  enabled:
    - kv
```

Or omit `capabilities:` entirely.

---

## Reading and writing values

```js
import { Kv } from "../lunejs/runtime/runtime.js";

// Write any JSON-serialisable value
await Kv.set("theme", "dark");
await Kv.set("window_scale", 1.5);
await Kv.set("recent_files", ["/tmp/a.txt", "/tmp/b.txt"]);

// Read back (returns null if the key doesn't exist)
const theme = await Kv.get("theme");
console.log(theme); // "dark"

const missing = await Kv.get("no_such_key");
console.log(missing); // null
```

---

## Checking and deleting keys

```js
const exists = await Kv.has("theme"); // true
await Kv.delete("theme");
const gone = await Kv.has("theme"); // false
```

---

## Listing and clearing

```js
const keys = await Kv.keys();
console.log(keys); // ["window_scale", "recent_files"]

await Kv.clear(); // removes all entries
```

---

## JavaScript API

| Method   | Signature                      | Description                           |
| -------- | ------------------------------ | ------------------------------------- |
| `get`    | `(key) → Promise<unknown>`     | Return the value or `null` if not set |
| `set`    | `(key, value) → Promise<void>` | Store any JSON-serialisable value     |
| `delete` | `(key) → Promise<void>`        | Remove a key; no-op if absent         |
| `has`    | `(key) → Promise<boolean>`     | Check whether a key exists            |
| `keys`   | `() → Promise<string[]>`       | List all stored keys                  |
| `clear`  | `() → Promise<void>`           | Remove all entries                    |

---

## Storage location

| Platform | Path                                                                |
| -------- | ------------------------------------------------------------------- |
| macOS    | `~/Library/Application Support/<app-name>/kv.json`                  |
| Linux    | `$XDG_DATA_HOME/<app-name>/kv.json` (default: `~/.local/share/...`) |
| Windows  | `%APPDATA%\<app-name>\kv.json`                                      |

`<app-name>` is derived from the app `title` in `lune.yml` (lowercased, spaces replaced with `-`).

---

## Notes

- **Values are JSON-serialised.** Numbers, strings, booleans, arrays, and objects are all valid. Functions and `undefined` cannot be stored.
- **Reads return `null` for missing keys**, not `undefined`, for consistent JSON round-tripping.
- **Writes flush to disk immediately.** There is no buffering; each `set`, `delete`, and `clear` call writes the whole file.
- **The `shutdown` lifecycle hook** calls `save_store` one final time on clean exit, guarding against any write that was skipped due to an error.

---

## Platform notes

- **macOS** — Verified.
- **Linux** — Untested.
- **Windows** — Verified. Pure Crystal on top of `%APPDATA%`.

---

## Disabling

```yaml
capabilities:
  disabled:
    - kv
```
