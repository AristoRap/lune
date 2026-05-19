# DeepLink

> Receive custom URL scheme events (`myapp://...`) from the OS.

|                  |               |
| ---------------- | ------------- |
| **Config key**   | `deep_link`   |
| **JS namespace** | `DeepLink`    |
| **Core**         | No            |
| **Phases**       | Bindable      |
| **Hard deps**    | `event_bus`   |
| **Platforms**    | macOS · Linux |

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

**Linux** — `lune dist` injects `MimeType=x-scheme-handler/myapp;` into the `.desktop` file. After installation, run `update-desktop-database`. The URL is passed as a command-line argument to the app process.

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

After distributing your AppImage, users need to register the `.desktop` file:

```sh
cp myapp.desktop ~/.local/share/applications/
update-desktop-database ~/.local/share/applications
```

> **Single-instance note:** If your app is already running when a URL is opened, Linux spawns a new process. The single-instance lock prevents a second window from opening, but the URL will be lost. Socket-based forwarding to the existing instance is not yet implemented.

---

## Disabling

```yaml
capabilities:
  exclude:
    - deep_link
```
