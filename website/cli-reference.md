# CLI Reference

The `lune` CLI manages your app's full lifecycle — scaffolding, development, building, and running.

Install the CLI via a pre-built binary or `make deploy` — see [Getting Started](./getting-started#install-the-cli).

---

## Global flags

These flags are accepted by all commands:

| Flag      | Description                  |
| --------- | ---------------------------- |
| `--debug` | Enable verbose debug logging |

---

## `lune init`

Scaffold a new Lune app.

```sh
lune init <APP_NAME> [flags]
```

**Arguments:**

| Argument   | Description                                                                                                                                  |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `APP_NAME` | Name of the app to create (required). Used as the directory name and Crystal project name. Spaces and slashes are replaced with underscores. |

**Flags:**

| Flag              | Short | Default   | Description                                                       |
| ----------------- | ----- | --------- | ----------------------------------------------------------------- |
| `--template`      | `-t`  | `vanilla` | Frontend template to use. Options: `vanilla`, `vue`               |
| `--force`         | `-f`  | `false`   | Delete and reinitialize the app directory from scratch            |
| `--skip-existing` | `-k`  | `false`   | Skip files that already exist instead of failing                  |
| `--skip-install`  | `-s`  | `false`   | Skip running `shards install` and `npm install` after scaffolding |

**Examples:**

```sh
# Scaffold with default Vanilla JS template
lune init my_app

# Scaffold with Vue 3 template
lune init my_app --template vue

# Re-scaffold over an existing directory
lune init my_app --force

# Scaffold without running install (useful in CI)
lune init my_app --skip-install
```

---

## `lune dev`

Start the frontend dev server and Crystal backend together with hot reload.

```sh
lune dev
```

Alias: `d`

- Starts the Vite dev server (using `frontend.dev.cmd` from `lune.yml`, defaulting to `npm run dev`)
- Compiles the Crystal app and opens a native window pointing at the dev server URL
- Watches Crystal source files; recompiles and refreshes on change
- Prevents duplicate windows via single-instance lock

**Example:**

```sh
lune dev
```

---

## `lune build`

Build the frontend and compile the Crystal binary with the frontend embedded.

```sh
lune build [flags]
```

Alias: `b`

**Flags:**

| Flag        | Short | Default | Description                                                                       |
| ----------- | ----- | ------- | --------------------------------------------------------------------------------- |
| `--release` | `-r`  | `false` | Compile with Crystal's `--release` optimizations (slower compile, faster runtime) |

**What it does:**

1. Runs a Crystal pre-pass (`-Dbuild_mode`) to generate `App.js` / `App.d.ts`
2. Runs the frontend build command (default: `npm run build`)
3. Compiles the Crystal binary with the frontend assets embedded
4. **macOS:** if [`mac.sign`](./configuration.md#macsign) is set in `lune.yml`, runs `codesign` on the output to enable `UNUserNotificationCenter`

**Output:**

- **macOS:** `build/bin/<app_name>.app` (app bundle)
- **Linux:** `build/bin/<app_name>`

**Examples:**

```sh
# Development build
lune build

# Optimized release build
lune build --release
```

---

## `lune dist`

Package the built app into a platform-native distributable.

```sh
lune dist [flags]
```

Requires a prior `lune build`. The output format is chosen automatically based on the current platform, or set explicitly with a flag.

**Flags:**

| Flag              | Default | Description                                                   |
| ----------------- | ------- | ------------------------------------------------------------- |
| `--skip-notarize` | `false` | Skip notarization even if `mac.notarize: true` is set (macOS) |

**macOS — DMG:**

1. Copies the built `.app` into a staging directory alongside an `/Applications` symlink
2. Runs `hdiutil create` to produce a compressed `build/bin/<name>.dmg`
3. If `mac.notarize: true` and `APPLE_ID` / `APPLE_PASSWORD` / `APPLE_TEAM_ID` env vars are set:
   - Submits to Apple's notary service (`xcrun notarytool submit --wait`)
   - Staples the ticket (`xcrun stapler staple`) so Gatekeeper can verify offline

**Linux — AppImage:**

1. Assembles an AppDir (`usr/bin/<name>`, `AppRun`, `.desktop` entry, icon if available)
2. Runs `appimagetool` to produce `build/bin/<name>.AppImage`
3. Cleans up the AppDir

Requires `appimagetool` in `PATH` — download the binary for your architecture from the [appimagetool releases](https://github.com/AppImage/appimagetool/releases/tag/continuous).

**Output:**

| Platform | Output                      |
| -------- | --------------------------- |
| macOS    | `build/bin/<name>.dmg`      |
| Linux    | `build/bin/<name>.AppImage` |

**Examples:**

```sh
# Build → package (platform default)
lune build --release
lune dist

# macOS: package without notarizing (local testing)
lune dist --skip-notarize
```

See [Distribution](./guide/distribution) for the full signing and notarization setup.

---

## `lune run`

Launch the previously built binary.

```sh
lune run
```

Alias: `r`

Runs the artifact produced by `lune build`. Respects single-instance locking — a second `lune run` for the same app exits immediately if one is already running.

---

## `lune check`

Type-check the Crystal source without building.

```sh
lune check
```

Useful for fast feedback during development without going through a full compile.

---

## `lune doctor`

Verify your development environment and (optionally) the project's plugin registry.

```sh
lune doctor [flags]
```

**Flags:**

| Flag        | Default | Description                                                                                             |
| ----------- | ------- | ------------------------------------------------------------------------------------------------------- |
| `--plugins` | `false` | After the environment checks, also list the live plugin registration set (built-ins + `Lune.use` calls) |

**Environment checks:**

| Check           | What it verifies                                    |
| --------------- | --------------------------------------------------- |
| `crystal`       | Crystal is installed and reports a version          |
| `node`          | Node.js is installed                                |
| `npm`           | npm is installed                                    |
| `shards`        | `shards check` passes (all deps installed)          |
| `frontend deps` | `node_modules` directory exists in the frontend dir |
| `app entry`     | The configured Crystal entry file exists            |

**Plugin checks (always shown):**

The built-in registry is summarised with platform availability and soft-dep gaps. ✓ marks active, ✗ marks platform-filtered. A `soft dep <id> not active` annotation appears when a dependent's optional dep isn't in the active set.

With `--plugins`, the doctor compiles your app entry with `-Dlune_inspect`, short-circuits `Lune.run` after the registry is populated, and lists the live set — the same shape the running app would see, including any `Lune.use(MyPlugin.new)` calls your code makes. This catches "I registered it but the app doesn't see it" mismatches early.

**Example output:**

```
  ✓  crystal           Crystal 1.20.0 [...]
  ✓  node              v22.0.0
  ✓  npm               10.0.0
  ✓  shards            ok
  ✓  frontend deps     ok
  ✓  app entry         src/main.cr

  Plugins
    ✓  event            Event
    ✓  stream           Stream
    ✗  file_watch       FileWatch  (not available on win32)
    ✓  tray             Tray
    …
```

---

## `lune version`

Print the installed Lune version.

```sh
lune version
```
