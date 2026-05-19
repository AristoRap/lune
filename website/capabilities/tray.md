# Tray

> System tray icon with an optional dropdown menu.

|                  |                                                                           |
| ---------------- | ------------------------------------------------------------------------- |
| **Config key**   | `tray`                                                                    |
| **JS namespace** | `Tray`                                                                    |
| **Core**         | No                                                                        |
| **Phases**       | Bindable                                                                  |
| **Hard deps**    | —                                                                         |
| **Soft deps**    | `event_bus` (menu item clicks emitted as events when event_bus is active) |
| **Platforms**    | macOS · Linux¹                                                            |

¹ Requires XWayland on Wayland compositors.

Tray has a soft dependency on `event_bus`. When event_bus is active, tray icon clicks and menu item selections emit events automatically. When event_bus is absent, use the Crystal-side callbacks in the `opts.tray` block instead.

---

## Crystal options

Configure the tray in the `Lune.run` block:

```crystal
Lune.run(app) do |opts|
  opts.tray do |t|
    # Optional: custom Crystal callbacks (override the default event emit)
    t.on_click = -> { puts "Tray icon clicked" }
    t.on_menu_click = ->(id : String) { puts "Menu item: #{id}" }

    # Optional: override the event name used when emitting via event_bus
    t.event = "myTrayEvent"  # default: "trayEvent"
  end
end
```

| Option          | Type            | Default           | Description                                          |
| --------------- | --------------- | ----------------- | ---------------------------------------------------- |
| `event`         | `String`        | `"trayEvent"`     | Event name emitted via EventBus on click/menu-select |
| `on_click`      | `-> Nil`        | emit `trayEvent`  | Crystal callback for tray icon click                 |
| `on_menu_click` | `String -> Nil` | emit menu item id | Crystal callback for menu item selection             |

---

## JavaScript API

Show the tray icon, set a menu, and handle events:

```js
import { Tray, Events } from "../lunejs/runtime/runtime.js";

// Show the tray icon
await Tray.show("/assets/icon.png");

// Set a dropdown menu
await Tray.setMenu([
  { id: "show", label: "Show window" },
  { id: "quit", label: "Quit" },
]);

// Listen for tray events (requires event_bus)
Events.on("trayEvent", (id) => {
  if (id === "click" || id === "show") showWindow();
  if (id === "quit") System.quit();
});

// Update the icon dynamically
await Tray.setIcon("/assets/icon-active.png");

// Hide the tray icon
await Tray.hide();
```

| Method    | Signature        | Returns         | Description                 |
| --------- | ---------------- | --------------- | --------------------------- |
| `show`    | `show(iconPath)` | `Promise<void>` | Show tray icon from path    |
| `hide`    | `hide()`         | `Promise<void>` | Hide the tray icon          |
| `setIcon` | `setIcon(path)`  | `Promise<void>` | Swap the icon image         |
| `setMenu` | `setMenu(items)` | `Promise<void>` | Set the dropdown menu items |

### `TrayMenuItem`

```ts
interface TrayMenuItem {
  id: string;
  label: string;
}
```

---

## Events

When `event_bus` is active (the default), the tray icon emits on the bus:

| Trigger         | Event name                           | Payload                             |
| --------------- | ------------------------------------ | ----------------------------------- |
| Icon click      | `"trayEvent"` (or `opts.tray.event`) | `"click"`                           |
| Menu item click | same event name                      | The `id` string of the clicked item |

Override the event name:

```crystal
opts.tray do |t|
  t.event = "app-tray"  # Events.on("app-tray", ...) in JS
end
```

---

## Disabling

```yaml
capabilities:
  exclude:
    - tray
```
