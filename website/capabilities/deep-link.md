# DeepLink

> Receive custom URL scheme events (`myapp://...`) from the OS.

|                  |             |
| ---------------- | ----------- |
| **Config key**   | `deep_link` |
| **JS namespace** | `DeepLink`  |
| **Core**         | No          |
| **Phases**       | Bindable    |
| **Hard deps**    | `event_bus` |
| **Platforms**    | macOS       |

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

**Linux** — `lune dist` injects `MimeType=x-scheme-handler/myapp;` into the generated `.desktop` file, so the OS will associate the scheme with your app at install time. However, there is **no runtime handler yet** — the launched process receives the URL as `ARGV[1]` but Lune does not currently parse it or fire `DeepLink.on`. See [Roadmap](#roadmap) below.

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

Linux runtime support is not implemented in this release. `lune dist` writes the scheme into the `.desktop` file so the OS will route URLs to your binary, but the Crystal runtime does not yet inspect `ARGV` or forward URLs to `event_bus`, so `DeepLink.on` will not fire. Treat this capability as macOS-only until the work below lands.

---

## Roadmap

Planned for a follow-up release:

- Parse `ARGV` on startup for a registered scheme and emit the initial URL through `event_bus`.
- Socket-based forwarding to the running instance when the OS spawns a second process (warm-start case).

---

## Disabling

```yaml
capabilities:
  exclude:
    - deep_link
```
