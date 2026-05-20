# Notifications

> Send native OS desktop notifications.

|                  |                                                             |
| ---------------- | ----------------------------------------------------------- |
| **Config key**   | `notifications`                                             |
| **JS namespace** | `Notifications`                                             |
| **Core**         | No                                                          |
| **Phases**       | Bindable                                                    |
| **Hard deps**    | —                                                           |
| **Platforms**    | macOS · Linux · Windows (Windows: PowerShell + WinRT toast) |

---

## JavaScript API

```js
import { Notifications } from "../lunejs/runtime/runtime.js";

await Notifications.notify("Build complete", "Your app compiled successfully.");
```

| Method   | Signature             | Returns         |
| -------- | --------------------- | --------------- |
| `notify` | `notify(title, body)` | `Promise<void>` |

---

## Notes

- On macOS, the notification is sent via `NSUserNotificationCenter`. The app must be running; there is no persistence.
- On Linux, `libnotify` is used. Requires `libnotify-dev` at build time.
- Clicking the notification does not currently emit an event back to the app.

---

## Disabling

```yaml
capabilities:
  exclude:
    - notifications
```
