# Deep Links

Register a custom URL scheme (e.g. `myapp://`) so the OS routes URLs into your running app. This is essential for OAuth redirect flows, shell integrations, and any scenario where an external trigger needs to open your app and pass data to it.

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

Scheme names must be lowercase alphanumeric. Avoid generic names that could conflict with other apps.

---

## How it works

**macOS** — `lune build` injects `CFBundleURLTypes` entries into `Info.plist`. After the app is installed (or run once from Finder), macOS registers the scheme automatically. When a user opens `myapp://...`, the OS routes it to your running app via Apple Events. No second instance is launched.

**Linux** — `lune dist` injects `MimeType=x-scheme-handler/myapp;` into the `.desktop` file inside the AppImage. After installation, run `update-desktop-database` to register the scheme. When a URL is opened, the OS passes it as a command-line argument (`$1`) to the app process.

---

## Receiving URLs in JavaScript

```js
import { DeepLink } from "../lunejs/runtime/runtime.js";

DeepLink.onDeepLink((url) => {
  console.log("Opened via:", url);
  // e.g. "myapp://oauth/callback?code=abc123"
});
```

Call `DeepLink.onDeepLink` early (top-level module scope or `onMounted`) so the handler is registered before the first event fires.

To stop listening:

```js
DeepLink.onDeepLinkOff();
```

---

## Platform notes

### macOS

Scheme registration is **build-time only** — there is no runtime registration API on macOS. The `CFBundleURLTypes` entry must be in `Info.plist` before the app is installed.

During development (`lune dev`) URL scheme routing is not active because the binary isn't a proper `.app` bundle. Test deep links against a `lune build` output.

### Linux

After distributing your AppImage, users need to register the `.desktop` file:

```sh
# Install the AppImage
./MyApp.AppImage --install   # if your AppImage supports it, or manually:

cp MyApp.AppImage ~/.local/bin/myapp
cp myapp.desktop ~/.local/share/applications/
update-desktop-database ~/.local/share/applications
```

The OS passes the URL as the first argument (`ARGV[1]`) when launching the app. Lune reads this on startup and emits the `deep_link` event automatically.

> **Single-instance note:** If your app is already running when a URL is opened, Linux spawns a new process. Lune's single-instance lock will prevent a second window from opening, but the URL will be lost in this case. Full socket-based forwarding to the existing instance is not yet implemented.

---

## OAuth redirect example

A typical OAuth flow:

1. Your app opens the browser to the provider's auth URL:
   ```js
   import { Lifecycle } from "../lunejs/runtime/runtime.js";
   Lifecycle.openUrl(
     "https://provider.com/oauth/authorize?redirect_uri=myapp://oauth/callback&...",
   );
   ```
2. The user authenticates in the browser.
3. The provider redirects to `myapp://oauth/callback?code=abc123`.
4. The OS routes the URL back to your app:
   ```js
   DeepLink.onDeepLink((url) => {
     const params = new URL(url).searchParams;
     const code = params.get("code");
     exchangeCodeForToken(code);
   });
   ```
