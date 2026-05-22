# Notifications

> Send native OS desktop notifications.

|                  |                         |
| ---------------- | ----------------------- |
| **Config key**   | `notifications`         |
| **JS namespace** | `Notifications`         |
| **Core**         | No                      |
| **Phases**       | Bindable                |
| **Hard deps**    | —                       |
| **Platforms**    | macOS · Linux · Windows |

---

## JavaScript API

```js
import { lune } from "../lunejs/runtime/runtime.js";

await lune.Notifications.notify(
  "Build complete",
  "Your app compiled successfully.",
);
```

| Method   | Signature             | Returns         |
| -------- | --------------------- | --------------- |
| `notify` | `notify(title, body)` | `Promise<void>` |

---

## Notes

- On macOS, the notification is sent via `NSUserNotificationCenter`. The app must be running; there is no persistence.
- On Linux, `libnotify` is used. Requires `libnotify-dev` at build time.
- On Windows, toasts are dispatched via a PowerShell + WinRT script (`Windows.UI.Notifications` + `Windows.Data.Xml.Dom`). The AUMID `Lune` is auto-registered at `HKCU\Software\Classes\AppUserModelId\Lune` on first call, so toasts surface and persist in Action Center out of the box.
- Clicking the notification does not currently emit an event back to the app.

---

## Platform notes

- **macOS** — Verified. Uses `NSUserNotificationCenter`; no persistence.
- **Linux** — Untested. Uses `libnotify` (requires `libnotify-dev` at build time).
- **Windows** — Verified. PowerShell + WinRT toast; AUMID `Lune` auto-registered at `HKCU\Software\Classes\AppUserModelId\Lune` on first call.

---

## Disabling

```yaml
plugins:
  disabled:
    - notifications
```
