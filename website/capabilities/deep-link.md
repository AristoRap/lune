# DeepLink

> Receive custom URL scheme events (`myapp://...`) from the OS.

|                  |                                                                           |
| ---------------- | ------------------------------------------------------------------------- |
| **Config key**   | `deep_link`                                                               |
| **JS namespace** | `DeepLink`                                                                |
| **Core**         | No                                                                        |
| **Phases**       | Bindable                                                                  |
| **Hard deps**    | `event_bus`                                                               |
| **Platforms**    | macOS · Linux · Windows (Windows: cold-start ARGV only — see Limitations) |

Register a custom URL scheme so the OS routes URLs into your running app — for OAuth redirects, shell integrations, or any external trigger that needs to pass data to your app.

Disabling `event_bus` automatically disables this capability.

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

1. **Cold start** — the OS launches a fresh app with the URL on the command line. Lune scans `ARGV` for an arg containing `://` and fires `DeepLink.on` with that URL.
2. **Warm start** — the OS launches a second process while the primary is already running. The second process tries to connect to a Unix-domain socket at `$XDG_RUNTIME_DIR/lune-<slug>.sock` (or `/tmp/…` if XDG isn't set); on success it forwards the URL and exits, and the primary instance fires `DeepLink.on` instead. If no primary is listening, the second instance continues as the new primary.

**Windows** — `myapp://` schemes need to be registered in the registry (`HKCU\Software\Classes\myapp\shell\open\command` → `"C:\path\to\app.exe" "%1"`) — Lune doesn't auto-register today. Once registered, the OS launches a fresh app with the URL on the command line and Lune scans `ARGV` like on Linux. Warm-start forwarding is not yet implemented on Windows (will use a named pipe in a follow-up).

---

## JavaScript API

```js
import { DeepLink } from "../lunejs/runtime/runtime.js";

DeepLink.on((url) => {
  console.log("Opened via:", url);
  // e.g. "myapp://oauth/callback?code=abc123"
});

// Stop listening
DeepLink.off();
```

Call `DeepLink.on` early (top-level module scope or `onMounted`) so the handler is registered before the first event fires.

| Method | Signature | Description                                            |
| ------ | --------- | ------------------------------------------------------ |
| `on`   | `on(cb)`  | Persistent listener; `cb` receives the full URL string |
| `off`  | `off()`   | Remove all listeners                                   |

---

## OAuth redirect example

```js
import { System, DeepLink } from "../lunejs/runtime/runtime.js";

// 1. Open browser to auth URL
System.openUrl(
  "https://provider.com/oauth/authorize?redirect_uri=myapp://oauth/callback&...",
);

// 2. Handle the redirect
DeepLink.on((url) => {
  const code = new URL(url).searchParams.get("code");
  exchangeCodeForToken(code);
});
```

---

## Platform notes

### macOS

Scheme registration is build-time only — `Info.plist` must contain `CFBundleURLTypes` before the app is installed. During development (`lune dev`) URL scheme routing is not active; test against a `lune build` output.

### Linux

Cold-start and warm-start are both wired up — see [How it works](#how-it-works). URL scheme registration still requires the `.desktop` file from `lune dist`; `lune dev` runs don't get OS-level scheme routing.

### Windows

Cold-start works once the URL scheme is registered in the registry; warm-start (forwarding a URL from a second launch to a primary instance) isn't implemented yet. Track v0.12.0 for named-pipe IPC and auto-registration via `lune build`.

---

## Roadmap

Planned for follow-up releases:

- **Windows warm-start** — named-pipe IPC equivalent to Linux's Unix-socket forwarding.
- **Windows scheme auto-registration** — `lune build` writes `HKCU\Software\Classes\<scheme>\shell\open\command` for each entry in `url_schemes`.

---

## Disabling

```yaml
capabilities:
  exclude:
    - deep_link
```
