# SQLite

> Embedded database access with a typed JS bridge.

|                  |                      |
| ---------------- | -------------------- |
| **Config key**   | `sqlite`             |
| **JS namespace** | `Sqlite`             |
| **Core**         | No                   |
| **Phases**       | Bindable · Lifecycle |
| **Hard deps**    | —                    |
| **Platforms**    | all                  |

SQLite gives your app a local, embedded database backed by [crystal-lang/crystal-sqlite3](https://github.com/crystal-lang/crystal-sqlite3). Open as many databases as you need — each call to `Sqlite.open` returns an opaque handle you pass to subsequent operations. Use `:memory:` for an in-process database that lives only for the session, or an absolute path for a persistent file.

---

## Enabling

```yaml
capabilities:
  enabled:
    - sqlite
```

Or omit `capabilities:` entirely — SQLite is active by default.

---

## Opening and closing a database

```js
import { Sqlite } from "../lunejs/runtime/runtime.js";

// In-memory: cleared when closed
const db = await Sqlite.open(":memory:");

// Persistent file
const db = await Sqlite.open(
  "/Users/alice/Library/Application Support/myapp/data.db",
);

// Always close when done
await Sqlite.close(db);
```

---

## Executing statements

`Sqlite.exec` runs any statement that does not return rows — `CREATE`, `INSERT`, `UPDATE`, `DELETE`, `DROP`, etc. It returns `{ changes, lastInsertId }`.

```js
await Sqlite.exec(
  db,
  "CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT)",
  [],
);

const { changes, lastInsertId } = await Sqlite.exec(
  db,
  "INSERT INTO notes (body) VALUES (?)",
  ["Hello, Lune!"],
);
// changes → 1, lastInsertId → 1
```

Pass an empty array `[]` for statements with no parameters.

---

## Querying rows

`Sqlite.query` returns an array of plain objects, one per row, keyed by column name.

```js
const rows = await Sqlite.query(
  db,
  "SELECT id, body FROM notes ORDER BY id",
  [],
);
// [{ id: 1, body: "Hello, Lune!" }]

// Parameterised query
const filtered = await Sqlite.query(
  db,
  "SELECT * FROM notes WHERE body LIKE ?",
  ["%Lune%"],
);
```

---

## Parameter binding

All four SQLite placeholder styles are supported (`?`, `?N`, `@name`, `:name`, `$name`) — whichever your SQL uses, pass values positionally in the array for `?` placeholders.

```js
// Positional
await Sqlite.exec(db, "INSERT INTO t VALUES (?, ?)", [42, "hello"]);

// Named (pass an array of values in bind order)
await Sqlite.exec(db, "INSERT INTO t VALUES (:n, :s)", [42, "hello"]);
```

---

## Type mapping

| SQLite storage class | JavaScript type    |
| -------------------- | ------------------ |
| INTEGER              | `number` (integer) |
| REAL                 | `number` (float)   |
| TEXT                 | `string`           |
| BLOB                 | `string` (base64)  |
| NULL                 | `null`             |

---

## Error handling

Both `exec` and `query` reject with a `LuneError` on failure:

```js
import { LuneError, Sqlite } from "../lunejs/runtime/runtime.js";

try {
  await Sqlite.exec(db, "NOT VALID SQL", []);
} catch (err) {
  if (err instanceof LuneError) {
    console.error(err.code, err.message); // "sqlite_error" + driver message
  }
}
```

Accessing a database that was never opened (or already closed) throws `LuneError` with code `sqlite_not_open`.

---

## JavaScript API

| Method  | Signature                                                                | Description                      |
| ------- | ------------------------------------------------------------------------ | -------------------------------- |
| `open`  | `(path: string) → Promise<string>`                                       | Open or create a database        |
| `close` | `(db: string) → Promise<void>`                                           | Close and release the database   |
| `exec`  | `(db, sql, params) → Promise<{ changes: number; lastInsertId: number }>` | Run a non-SELECT statement       |
| `query` | `(db, sql, params) → Promise<Record<string, unknown>[]>`                 | Run a SELECT and return all rows |

---

## Notes

- **One pool per handle.** `crystal-sqlite3` manages a connection pool per `DB::Database` instance. SQLite's WAL mode is recommended for write-heavy apps with concurrent reads.
- **Lifecycle cleanup.** All open databases are closed when the app quits — the `Lifecycle` shutdown hook calls `db.close` on every tracked handle.
- **BLOB columns** arrive in JavaScript as base64-encoded strings.

---

## Platform notes

- **macOS** — Verified.
- **Linux** — Untested.
- **Windows** — Verified. Uses bundled `sqlite3.dll`; build requires the import library (see WINDOWS_SETUP.md).

---

## Disabling

```yaml
capabilities:
  disabled:
    - sqlite
```
