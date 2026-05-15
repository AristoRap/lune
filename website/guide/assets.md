# Assets & Build

For a production build, Lune embeds your entire frontend into the Crystal binary at compile time. The result is a single self-contained executable — no frontend files need to be present on disk at runtime.

---

## The `assets:` argument

Pass the path to your built frontend directory to `Lune.run` via the `assets:` keyword:

```crystal
Lune.run(app, assets: "frontend/dist") do |opts|
  opts.title = "My App"
end
```

**This is required for `lune build` to work.** Without it, the compiled binary has no frontend to serve and the window will be blank.

The path is relative to the Crystal source file where `Lune.run` is called (typically `src/main.cr`), so `"frontend/dist"` resolves correctly from the project root.

---

## What happens at compile time

The `assets:` argument triggers `Lune::Assets.embed_dir` — a compile-time macro that reads every file under the given directory and bakes its bytes directly into the binary:

```
frontend/dist/
├── index.html          → embedded as /index.html
├── assets/
│   ├── main-Cx3k9.js   → embedded as /assets/main-Cx3k9.js
│   └── style-BxQ2.css  → embedded as /assets/style-BxQ2.css
└── favicon.ico         → embedded as /favicon.ico
```

Each file is stored as a `Bytes` slice keyed by its URL path. No files are read from disk at runtime.

---

## What happens at runtime

When the app starts, an `AssetServer` (a small HTTP server) binds to a random local port and serves the embedded files. The WebView navigates to `http://127.0.0.1:<port>`.

Serving over a real `http://` origin — rather than a `file://` URI or inline `data:` URL — means the frontend behaves like a normal web page: relative imports, `fetch`, and browser security policies all work correctly.

---

## Dev mode vs production

`lune dev` sets the `LUNE_DEV_URL` environment variable, which takes precedence over any embedded assets. The WebView connects to your Vite dev server URL instead, so hot reload works normally without rebuilding the binary.

In production (`lune build` / `lune run`), `LUNE_DEV_URL` is not set, so the embedded assets are served.

| Mode                      | Frontend source                      |
| ------------------------- | ------------------------------------ |
| `lune dev`                | Vite dev server (`LUNE_DEV_URL`)     |
| `lune build` / `lune run` | Embedded files via local HTTP server |

You do not need to change any code between dev and production — the same `Lune.run(app, assets: "frontend/dist")` call handles both.

---

## Navigation priority

`Lune::Runner` resolves the WebView URL using this priority order (first match wins):

1. **`html:`** — inline HTML string passed to `runner.start`
2. **`url:`** — explicit URL passed to `runner.start`
3. **`LUNE_DEV_URL` env var** — set automatically by `lune dev`; points to the Vite dev server
4. **`assets:`** — directory embedded at compile time, served over a local HTTP server

When using the `Lune.run` macro, only LUNE_DEV_URL and `assets:` apply — the macro always calls `runner.start` with no arguments. `html:` and `url:` are only available when using `Lune::Runner` directly (see [How It Works](./how-it-works)).

---

## Build order

`lune build` handles the sequencing automatically:

1. Runs Crystal in pre-pass mode (`-Dbuild_mode`) to generate `App.js` / `App.d.ts`
2. Runs `npm run build` (or your configured `frontend.build` command) to produce `frontend/dist/`
3. Compiles the Crystal binary — the `assets: "frontend/dist"` macro reads the just-built dist directory and embeds it

This means `frontend/dist/` must exist before step 3. If you compile Crystal manually (outside of `lune build`), run your frontend build first.

---

## Supported file types

The embedded HTTP server recognises these content types automatically:

| Extension                         | MIME type                  |
| --------------------------------- | -------------------------- |
| `.html`                           | `text/html; charset=utf-8` |
| `.js`, `.mjs`                     | `application/javascript`   |
| `.css`                            | `text/css`                 |
| `.json`                           | `application/json`         |
| `.png`, `.jpg`, `.gif`, `.webp`   | `image/*`                  |
| `.svg`                            | `image/svg+xml`            |
| `.ico`                            | `image/x-icon`             |
| `.woff`, `.woff2`, `.ttf`, `.eot` | `font/*`                   |
| `.map`                            | `application/json`         |
| anything else                     | `application/octet-stream` |
