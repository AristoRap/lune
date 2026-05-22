# Distribution

The distribution pipeline is two commands regardless of platform:

```sh
lune build --release   # compile and sign
lune dist              # package for distribution
```

`lune dist` auto-detects the platform and produces the appropriate format — DMG on macOS, AppImage on Linux.

---

## macOS

### Prerequisites

- An **Apple Developer Program** membership (required for signing and notarization)
- A **Developer ID Application** certificate installed in your Keychain
- Xcode Command Line Tools (`xcode-select --install`)

### Code signing

Set your signing identity in `lune.yml`:

```yaml
mac:
  sign: "Developer ID Application: Your Name (TEAMID)"
```

`lune build` passes this to `codesign --force --deep --options runtime --entitlements <plist> --sign <identity>`. The hardened runtime flag is required for notarization.

#### Entitlements

WKWebView requires two entitlements under the hardened runtime. Lune generates them automatically — you don't need a custom plist unless your app needs additional plugins.

If you do (e.g. camera, microphone), create a plist and point to it:

```yaml
mac:
  sign: "Developer ID Application: Your Name (TEAMID)"
  entitlements: assets/entitlements.plist
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.cs.allow-jit</key>
  <true/>
  <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
  <true/>
  <key>com.apple.security.network.client</key>
  <true/>
</dict>
</plist>
```

#### Finding your signing identity

```sh
security find-identity -v -p codesigning
```

Copy the string in quotes — that's your `mac.sign` value.

### DMG packaging

```sh
lune dist
```

Creates `build/bin/<name>.dmg` containing your `.app` and an `/Applications` symlink — the standard macOS drag-to-install layout. No external tools required; Lune uses `hdiutil` which ships with macOS.

### Notarization

Apple's notary service verifies your app is malware-free. Without it, Gatekeeper blocks the app on other machines.

**Setup:**

1. Create an **app-specific password** at [appleid.apple.com](https://appleid.apple.com) → Security → App-Specific Passwords.
2. Find your **Team ID** at [developer.apple.com/account](https://developer.apple.com/account) → Membership.
3. Enable notarization in `lune.yml`:

```yaml
mac:
  sign: "Developer ID Application: Your Name (TEAMID)"
  notarize: true
```

4. Export credentials before running `lune dist`:

```sh
export APPLE_ID="you@example.com"
export APPLE_PASSWORD="xxxx-xxxx-xxxx-xxxx"
export APPLE_TEAM_ID="ABCD123456"
```

`lune dist` submits the DMG, waits for Apple's result (typically under a minute), and staples the ticket so Gatekeeper can verify offline.

**CI/CD (GitHub Actions):**

```yaml
- name: Build and package
  env:
    APPLE_ID: ${{ secrets.APPLE_ID }}
    APPLE_PASSWORD: ${{ secrets.APPLE_PASSWORD }}
    APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
  run: |
    lune build --release
    lune dist
```

**Skip notarization for local testing:**

```sh
lune dist --skip-notarize
```

### Bundle identifier

`CFBundleIdentifier` defaults to `dev.lune.<app_name>`. Override it:

```yaml
mac:
  bundle_id: com.example.myapp
```

### Full `lune.yml` example

```yaml
name: My App
icon: assets/icon.icns

mac:
  sign: "Developer ID Application: Your Name (TEAMID)"
  bundle_id: com.example.myapp
  notarize: true
```

---

## Linux

### Prerequisites

- **`appimagetool`** in your `PATH` — download the binary for your architecture from [appimagetool releases](https://github.com/AppImage/appimagetool/releases/tag/continuous).

```sh
# x86_64
curl -Lo appimagetool https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool
sudo mv appimagetool /usr/local/bin/

# ARM64
curl -Lo appimagetool https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-aarch64.AppImage
chmod +x appimagetool
sudo mv appimagetool /usr/local/bin/
```

### AppImage packaging

```sh
lune dist
```

Creates `build/bin/<name>.AppImage` — a self-contained single-file executable that runs on any Linux distro without installation. Lune assembles the AppDir structure automatically:

```
<name>.AppDir/
  AppRun              ← entry point script
  <name>.desktop      ← desktop entry (name, icon, category)
  <name>.png          ← icon (if icon is set in lune.yml)
  usr/bin/<name>      ← the compiled binary
```

No signing or notarization step — Linux has no enforced app signing equivalent.

### Icon

Set `icon` in `lune.yml` pointing to a PNG — Lune copies it into the AppDir automatically:

```yaml
icon: assets/icon.png
```

### Full `lune.yml` example

```yaml
name: My App
icon: assets/icon.png
```
