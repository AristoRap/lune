# Notifications

> Send native OS desktop notifications.

|                  |                          |
| ---------------- | ------------------------ |
| **Config key**   | `notifications`          |
| **JS namespace** | `Notifications`          |
| **Core**         | No                       |
| **Phases**       | Bindable                 |
| **Hard deps**    | —                        |
| **Platforms**    | macOS · Linux · Windows¹ |

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

¹ **Windows note** — the PowerShell + WinRT toast script runs cleanly (both `Windows.UI.Notifications` and `Windows.Data.Xml.Dom` projections are loaded explicitly), but Windows silently drops the toast because the AUMID `"Lune"` isn't registered with the OS. To actually see notifications, the AUMID needs a Start Menu shortcut with its `System.AppUserModel.ID` property set — distributed apps should bake this into their installer. Tracked under "Windows toast notifications" in [`ROADMAP.md`](https://github.com/AristoRap/lune/blob/main/ROADMAP.md).

---

## Disabling

```yaml
capabilities:
  disabled:
    - notifications
```
