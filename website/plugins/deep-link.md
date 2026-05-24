# DeepLink

> Receive custom URL scheme events (`myapp://...`) from the OS.

|                  |                                                                           |
| ---------------- | ------------------------------------------------------------------------- |
| **Config key**   | `deep_link`                                                               |
| **JS namespace** | `DeepLink`                                                                |
| **Core**         | No                                                                        |
| **Phases**       | Bindable                                                                  |
| **Hard deps**    | `event`                                                                   |
| **Platforms**    | macOS · Linux · Windows (Windows: cold-start ARGV only — see Limitations) |

Register a custom URL scheme so the OS routes URLs into your running app — for OAuth redirects, shell integrations, or any external trigger that needs to pass data to your app.

Disabling `event` automatically disables this plugin.

---

## Configuration

Add `url_schemes` to `lune.yml`:

```yaml
name: MyApp
url_schemes:
  - myapp
```

Multiple schemes are supported:

```yaml
url_schemes:
  - myapp
  - myapp-alt
```

Scheme names must be lowercase alphanumeric.

---

## How it works

**macOS** — `lune build` injects `CFBundleURLTypes` into `Info.plist`. After the app is installed (or run once from Finder), macOS registers the scheme automatically. URLs are routed to the running instance via Apple Events.

**Linux** — `lune dist` injects `MimeType=x-scheme-handler/myapp;` into the generated `.desktop` file, so the OS associates the scheme with your binary at install time. At runtime, Lune handles two cases:

1. **Cold start** — the OS launches a fresh app with the URL on the command line. Lune scans `ARGV` for an arg containing `://` and fires `lune.DeepLink.on` with that URL.
2. **Warm start** — the OS launches a second process while the primary is already running. The second process tries to connect to a Unix-domain socket at `$XDG_RUNTIME_DIR/lune-<slug>.sock` (or `/tmp/…` if XDG isn't set); on success it forwards the URL and exits, and the primary instance fires `lune.DeepLink.on` instead. If no primary is listening, the second instance continues as the new primary.

**Windows** — `myapp://` schemes need to be registered in the registry (`HKCU\Software\Classes\myapp\shell\open\command` → `"C:\path\to\app.exe" "%1"`) — Lune doesn't auto-register today. Once registered, the OS launches a fresh app with the URL on the command line and Lune scans `ARGV` like on Linux. Warm-start forwarding is not yet implemented on Windows (will use a named pipe in a follow-up).

---

## JavaScript API

```js
import { lune } from "../lunejs/runtime/runtime.js";

lune.DeepLink.on((url) => {
  console.log("Opened via:", url);
  // e.g. "myapp://oauth/callback?code=abc123"
});

// Stop listening
lune.DeepLink.off();
```

Call `lune.DeepLink.on` early (top-level module scope or `onMounted`) so the handler is registered before the first event fires.

| Method | Signature | Description                                            |
| ------ | --------- | ------------------------------------------------------ |
| `on`   | `on(cb)`  | Persistent listener; `cb` receives the full URL string |
| `off`  | `off()`   | Remove all listeners                                   |

---

## OAuth redirect example

```js
import { lune } from "../lunejs/runtime/runtime.js";

// 1. Open browser to auth URL
lune.System.openUrl(
  "https://provider.com/oauth/authorize?redirect_uri=myapp://oauth/callback&...",
);

// 2. Handle the redirect
lune.DeepLink.on((url) => {
  const code = new URL(url).searchParams.get("code");
  exchangeCodeForToken(code);
});
```

---

## Platform notes

- **macOS** — Verified, including cold-start. Scheme registration is build-time only via `Info.plist` `CFBundleURLTypes`; `lune dev` runs don't get OS-level scheme routing. Cold-start URLs (Apple Event delivered before the WebView has loaded) are captured by an early-registered Apple Event handler in the native shim and replayed once Crystal attaches its callback; the Event boot queue then holds the emit until the page is ready. Wire JS listeners at app-root scope (not on a single view) if you want cold-start URLs to reach handlers regardless of which view is mounted first.
- **Linux** — Untested. Cold-start and warm-start both wired; requires `.desktop` file from `lune dist`.
- **Windows** — Partial. Cold-start (ARGV) works once registered in the registry; warm-start forwarding and scheme auto-registration not yet implemented.

---

## Roadmap

Planned for follow-up releases:

- **Windows warm-start** — named-pipe IPC equivalent to Linux's Unix-socket forwarding.
- **Windows scheme auto-registration** — `lune build` writes `HKCU\Software\Classes\<scheme>\shell\open\command` for each entry in `url_schemes`.

---

## Disabling

```yaml
plugins:
  disabled:
    - deep_link
```
