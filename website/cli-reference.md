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

Verify your development environment.

```sh
lune doctor
```

Checks for:

| Check           | What it verifies                                    |
| --------------- | --------------------------------------------------- |
| `crystal`       | Crystal is installed and reports a version          |
| `node`          | Node.js is installed                                |
| `npm`           | npm is installed                                    |
| `shards`        | `shards check` passes (all deps installed)          |
| `frontend deps` | `node_modules` directory exists in the frontend dir |
| `app entry`     | The configured Crystal entry file exists            |

**Example output:**

```
  ✓  crystal           Crystal 1.20.0 [...]
  ✓  node              v22.0.0
  ✓  npm               10.0.0
  ✓  shards            ok
  ✓  frontend deps     ok
  ✓  app entry         src/main.cr
```

---

## `lune version`

Print the installed Lune version.

```sh
lune version
```
