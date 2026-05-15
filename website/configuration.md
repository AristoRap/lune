# Configuration

Lune reads an optional `lune.yml` file from the root of your project. All keys have sensible defaults so the file can be omitted entirely for simple projects.

---

## Full reference

```yaml
# App name (optional — used for display only)
name: my_app

# Allowed runtime bindings (default: all). Omit to expose everything.
capabilities:
  - quit
  - openURL
  - environment
  - homeDir
  - tempDir
  - downloadsDir
  - appDataDir
  - clipboardRead
  - clipboardWrite

# Crystal entry point (default: src/main.cr)
app_entry: src/main.cr

frontend:
  # Frontend directory (default: frontend)
  dir: frontend

  # Command to install frontend dependencies (default: npm install)
  install: npm install

  # Command to build the frontend for production (default: npm run build)
  build: npm run build

  dev:
    # Command to start the dev server (default: npm run dev)
    cmd: npm run dev

    # URL the dev server listens on (default: http://localhost:5173)
    url: http://localhost:5173
```

---

## Key reference

### `name`

**Type:** `String?` — **Default:** `nil`

Optional display name for the app. Not used by the CLI toolchain — you can safely omit it.

---

### `app_entry`

**Type:** `String` — **Default:** `"src/main.cr"`

Path to your Crystal entry point, relative to the project root.

```yaml
app_entry: src/main.cr
```

---

### `frontend.dir`

**Type:** `String` — **Default:** `"frontend"`

Path to your frontend directory, relative to the project root. This is where Vite and npm commands are run from, and where `lunejs/` will be written.

```yaml
frontend:
  dir: frontend
```

---

### `frontend.install`

**Type:** `String?` — **Default:** `"npm install"`

Command used to install frontend dependencies. Shown as a hint in `lune doctor` output when `node_modules` is missing.

```yaml
frontend:
  install: pnpm install
```

---

### `frontend.build`

**Type:** `String?` — **Default:** `"npm run build"`

Command to build the frontend for production. Lune runs this during `lune build`, from inside `frontend.dir`.

```yaml
frontend:
  build: pnpm run build
```

---

### `frontend.dev.cmd`

**Type:** `String?` — **Default:** `"npm run dev"`

Command to start the dev server. Lune runs this during `lune dev`, from inside `frontend.dir`.

```yaml
frontend:
  dev:
    cmd: pnpm run dev
```

---

### `frontend.dev.url`

**Type:** `String` — **Default:** `"http://localhost:5173"`

URL that the dev server listens on. Lune opens the native WebView to this URL when `lune dev` starts.

```yaml
frontend:
  dev:
    url: http://localhost:3000
```

---

### `window`

All `Lune::Options` properties can also be declared here. Values set in `lune.yml` become the defaults for the window; the opts block in your Crystal code can still override any of them.

```yaml
window:
  title: My App # String   — window title bar text
  width: 1440 # Int      — initial width in logical pixels
  height: 900 # Int      — initial height in logical pixels
  min_width: 900 # Int      — minimum resizable width
  min_height: 600 # Int      — minimum resizable height
  max_width: 1920 # Int      — maximum resizable width
  max_height: 1080 # Int      — maximum resizable height
  resizable: true # Bool     — whether the window can be resized
  debug: false # Bool     — enable WebView devtools
```

All keys are optional. Omitted keys fall back to the `Lune::Options` defaults (`title: "Lune"`, `width: 1200`, `height: 800`, `resizable: true`, `debug: false`).

---

### `capabilities`

**Type:** `Array(String)?` — **Default:** `nil` (all runtime bindings exposed)

Restricts which built-in runtime bindings are accessible from JavaScript. When omitted, all bindings are available. When set, only the listed names are registered — any others are silently excluded.

Available capability names: `quit`, `openURL`, `environment`, `homeDir`, `tempDir`, `downloadsDir`, `appDataDir`, `clipboardRead`, `clipboardWrite`.

```yaml
capabilities:
  - quit
  - openURL
  - clipboardRead
  - clipboardWrite
```

---

## Example: using pnpm

```yaml
name: my_app

frontend:
  install: pnpm install
  build: pnpm run build
  dev:
    cmd: pnpm run dev
    url: http://localhost:5173
```

## Example: custom port

```yaml
frontend:
  dev:
    url: http://localhost:4000
```

## Example: non-standard project layout

```yaml
app_entry: src/app/main.cr

frontend:
  dir: packages/ui
  build: npm run build:prod
  dev:
    cmd: npm run start
    url: http://localhost:8080
```
