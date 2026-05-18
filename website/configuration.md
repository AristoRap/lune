# Configuration

Lune reads an optional `lune.yml` file from the root of your project. All keys have sensible defaults so the file can be omitted entirely for simple projects.

---

## Full reference

```yaml
# App name (optional — used for display only)
name: my_app

# Path to the app icon asset, relative to the project root (optional)
icon: assets/icon.icns

# Active capabilities (default: all). Omit to expose everything.
capabilities:
  include:
    - lifecycle
    - clipboard
  exclude:
    - clipboard

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

# macOS-specific options (optional)
mac:
  # Code-signing identity applied via codesign after lune build (optional).
  # Required for UNUserNotificationCenter in production builds.
  sign: "Developer ID Application: Your Name (TEAMID)"

  # CFBundleIdentifier override (default: dev.lune.<app_name>)
  bundle_id: com.example.myapp

  # Path to a custom entitlements plist (optional — Lune provides sensible defaults)
  entitlements: assets/entitlements.plist

  # Submit DMG to Apple's notary service after lune dist (default: false)
  # Credentials must be set via APPLE_ID, APPLE_PASSWORD, APPLE_TEAM_ID env vars
  notarize: true

# Custom URL schemes to register with the OS (optional)
# macOS: injected into CFBundleURLTypes in Info.plist by lune build
# Linux: injected as MimeType entries in the .desktop file by lune dist
url_schemes:
  - myapp
```

---

## Key reference

### `name`

**Type:** `String?` — **Default:** `nil`

Optional display name for the app. Not used by the CLI toolchain — you can safely omit it.

---

### `icon`

**Type:** `String?` — **Default:** `nil`

Path to the app icon asset, relative to the project root. Used by `lune build` to bundle the icon into the platform output. Has no effect during `lune dev`.

```yaml
icon: assets/icon.icns
```

| Platform | Expected format | Where it ends up                                                                            |
| -------- | --------------- | ------------------------------------------------------------------------------------------- |
| macOS    | `.icns`         | `MyApp.app/Contents/Resources/<filename>`, registered as `CFBundleIconFile` in `Info.plist` |
| Linux    | `.png`          | Copied next to the binary                                                                   |

If the file is missing at build time, a warning is logged and the build continues without an icon. On macOS, `iconutil` (ships with Xcode) converts a `.iconset` folder to `.icns`:

```sh
iconutil -c icns MyApp.iconset -o assets/icon.icns
```

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

### `mac.sign`

**Type:** `String?` — **Default:** `nil` — **Platform:** macOS only

Code-signing identity passed to `codesign --force --deep --options runtime --entitlements <plist> --sign <identity>` after `lune build` completes. The value must match a certificate installed in your Keychain (e.g. from Apple Developer Program).

```yaml
mac:
  sign: "Developer ID Application: Your Name (TEAMID)"
```

When set and the identity is valid, the built `.app` carries a certificate-backed signature. The Lune runtime detects this at launch and routes `notify()` calls to `UNUserNotificationCenter` instead of the `osascript` fallback.

If the identity is missing, invalid, or `codesign` fails, a warning is logged and the build continues — notifications silently fall back to `osascript`.

---

### `mac.entitlements`

**Type:** `String?` — **Default:** `nil` — **Platform:** macOS only

Path to a custom entitlements `.plist` file, relative to the project root. Passed to `codesign` when [`mac.sign`](#macsign) is set.

```yaml
mac:
  sign: "Developer ID Application: Your Name (TEAMID)"
  entitlements: assets/entitlements.plist
```

If omitted, Lune generates a minimal default plist that includes the entitlements WKWebView requires under hardened runtime:

```xml
<key>com.apple.security.cs.allow-jit</key>
<true/>
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

Provide a custom file only when your app needs additional capabilities (e.g. camera, microphone, file access beyond the sandbox).

---

### `mac.bundle_id`

**Type:** `String?` — **Default:** `nil` — **Platform:** macOS only

Overrides the `CFBundleIdentifier` written into `Info.plist`. When omitted, Lune derives an identifier from the app name: `dev.lune.<app_name>`.

```yaml
mac:
  bundle_id: com.example.myapp
```

Set this when distributing through the App Store or when your notarization profile is tied to a specific bundle identifier.

---

### `mac.notarize`

**Type:** `Bool` — **Default:** `false` — **Platform:** macOS only

When `true`, `lune dist` submits the packaged DMG to Apple's notary service and staples the ticket. Credentials are read from environment variables — never stored in `lune.yml`:

| Env var          | Description                               |
| ---------------- | ----------------------------------------- |
| `APPLE_ID`       | Your Apple ID email address               |
| `APPLE_PASSWORD` | An app-specific password (not your login) |
| `APPLE_TEAM_ID`  | Your 10-character Team ID                 |

```yaml
mac:
  sign: "Developer ID Application: Your Name (TEAMID)"
  notarize: true
```

See [Distribution → Notarization](./guide/distribution#notarization) for the full setup.

---

### `url_schemes`

**Type:** `Array(String)` — **Default:** `[]`

URL schemes to register with the OS so the system routes `myapp://...` links into your app. Each entry becomes a `CFBundleURLTypes` entry in `Info.plist` (macOS, injected by `lune build`) or a `MimeType` entry in the `.desktop` file (Linux, injected by `lune dist`).

```yaml
url_schemes:
  - myapp
```

After receiving a URL the `deep_link` runtime event fires in JavaScript:

```js
import { DeepLink } from "lune/runtime";
DeepLink.OnDeepLink((url) => {
  /* url = "myapp://..." */
});
```

See [Deep Links](./guide/deep-links) for the full guide.

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

**Default:** all capabilities enabled (both `include` and `exclude` omitted)

Controls which built-in capabilities are active. The unit is a **capability** — a named group of related functions. `include` is resolved first, then `exclude` is subtracted. Both keys accept `"*"` or `"all"` as explicit wildcards.

Values must be **capability names** (e.g. `lifecycle`, `clipboard`). Individual function names like `quit` are not valid — they will log a warning and be ignored.

| `include`                    | `exclude`            | result               |
| ---------------------------- | -------------------- | -------------------- |
| omitted or `[]`              | omitted              | all capabilities     |
| `["lifecycle"]`              | omitted              | lifecycle only       |
| `["*"]` or `["all"]`         | omitted              | all (explicit)       |
| omitted or `[]`              | `["clipboard"]`      | all except clipboard |
| omitted                      | `["*"]` or `["all"]` | none                 |
| `["lifecycle", "clipboard"]` | `["clipboard"]`      | only lifecycle       |

See [Runtime → Capabilities](./guide/runtime#capabilities) for the full list of capability names and the functions each one controls.

#### Dev vs build behaviour

- **Dev mode** (`lune dev`) — the bridge is filtered: excluded capability functions throw if called. `runtime.js` still includes all capabilities so the dev Capabilities view can show which are active vs excluded, and imports keep working while you iterate.
- **Build mode** (`lune build`) — both the bridge and `runtime.js` are filtered. Importing an excluded function is a hard bundler error.

Any unknown name in `include` or `exclude` logs a warning at startup and is ignored.

```yaml
# expose only the lifecycle capability
capabilities:
  include:
    - lifecycle

# expose everything except file dialogs
capabilities:
  exclude:
    - dialogs

# expose lifecycle and clipboard, then remove clipboard
capabilities:
  include:
    - lifecycle
    - clipboard
  exclude:
    - clipboard
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
