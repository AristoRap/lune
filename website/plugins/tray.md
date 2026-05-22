# Tray

> System tray icon with an optional dropdown menu.

|                  |                                                                     |
| ---------------- | ------------------------------------------------------------------- |
| **Config key**   | `tray`                                                              |
| **JS namespace** | `Tray`                                                              |
| **Core**         | No                                                                  |
| **Phases**       | Bindable                                                            |
| **Hard deps**    | —                                                                   |
| **Soft deps**    | `events` (menu item clicks emitted as events when events is active) |
| **Platforms**    | macOS · Linux¹ · Windows²                                           |

¹ Requires XWayland on Wayland compositors.

² Windows: `Tray.setIcon` requires a `.ico` path (PNG / SVG fall back to the default Windows app icon with a logger warning). See [Windows notes](#windows-notes) below.

Tray has a soft dependency on `events`. When events is active, tray icon clicks and menu item selections emit events automatically. When events is absent, use the Crystal-side callbacks in the `opts.tray` block instead.

---

## Click model

Per click direction (left or right), the first rule that matches wins:

1. **User override set** (`on_click` / `on_right_click`) — fires the callback. Full takeover.
2. **Click listed in `toggle_window_on`** — toggles the window (positioned under the tray icon on macOS).
3. **A menu is set** — pops it up.
4. **Otherwise** — emits `trayEvent` with payload `"left_click"` or `"right_click"`.

Left and right are independently configurable. Setting a menu wires it to both clicks (rule 3) unless that click is captured by an earlier rule.

---

## Crystal options

Configure the tray in the `Lune.run` block:

```crystal
Lune.run(app) do |opts|
  opts.tray do |t|
    # Optional: which clicks toggle the window under the tray icon (macOS).
    t.toggle_window_on = [:left_click]

    # Optional: custom Crystal callbacks (override every default for that click).
    t.on_click       = -> { puts "left clicked" }
    t.on_right_click = -> { puts "right clicked" }
    t.on_menu_click  = ->(id : String) { puts "menu: #{id}" }

    # Optional: override the event name used when emitting via events.
    t.event = "myTrayEvent"  # default: "trayEvent"

    # Optional: show the tray icon at boot without a JS `Tray.show("")` call.
    # Auto-enabled by `mac.menubar_mode`.
    t.auto_show = true
  end
end
```

| Option             | Type            | Default           | Description                                                  |
| ------------------ | --------------- | ----------------- | ------------------------------------------------------------ |
| `event`            | `String`        | `"trayEvent"`     | Event name emitted via Events on click / menu select         |
| `on_click`         | `-> Nil`        | —                 | Crystal callback for left-click (full takeover)              |
| `on_right_click`   | `-> Nil`        | —                 | Crystal callback for right-click (full takeover)             |
| `on_menu_click`    | `String -> Nil` | emit menu item id | Crystal callback for menu item selection                     |
| `toggle_window_on` | `Array(Symbol)` | `[]`              | Clicks that toggle the window. `:left_click`, `:right_click` |
| `auto_show`        | `Bool`          | `false`           | Show the tray icon at boot (set by `mac.menubar_mode`)       |

---

## JavaScript API

Show the tray icon, set a menu, and handle events:

```js
import { Tray, Events, System } from "../lunejs/runtime/runtime.js";

// Show the tray icon
await Tray.show("/assets/icon.png");

// Set a dropdown menu
await Tray.setMenu([
  { id: "show", label: "Show window" },
  { id: "---", label: "" }, // separator
  { id: "quit", label: "Quit" },
]);

// Listen for tray events (requires events)
Events.on("trayEvent", (payload) => {
  if (payload === "left_click") console.log("plain left click");
  if (payload === "right_click") console.log("plain right click");
  if (payload === "show") Window.show();
  if (payload === "quit") System.quit();
});

// Open the menu programmatically (no-op if no menu set)
await Tray.popupMenu();

// Update the icon dynamically
await Tray.setIcon("/assets/icon-active.png");

// Hide the tray icon
await Tray.hide();
```

| Method      | Signature        | Returns         | Description                      |
| ----------- | ---------------- | --------------- | -------------------------------- |
| `show`      | `show(iconPath)` | `Promise<void>` | Show tray icon from path         |
| `hide`      | `hide()`         | `Promise<void>` | Hide the tray icon               |
| `setIcon`   | `setIcon(path)`  | `Promise<void>` | Swap the icon image              |
| `setMenu`   | `setMenu(items)` | `Promise<void>` | Set the dropdown menu items      |
| `popupMenu` | `popupMenu()`    | `Promise<void>` | Open the menu (no-op if not set) |

### `TrayMenuItem`

```ts
interface TrayMenuItem {
  id: string; // unique id, use "---" for a separator
  label: string;
}
```

---

## Events

When `events` is active (the default), tray interactions emit on the bus:

| Trigger                              | Payload                             |
| ------------------------------------ | ----------------------------------- |
| Left-click (no override/toggle/menu) | `"left_click"`                      |
| Right-click (same conditions)        | `"right_click"`                     |
| Menu item selected                   | The `id` string of the clicked item |

Event name defaults to `"trayEvent"`. Override with `opts.tray.event`:

```crystal
opts.tray do |t|
  t.event = "app-tray"  # Events.on("app-tray", ...) in JS
end
```

---

## Recipes

**Both clicks show the menu (Docker style):**

```crystal
# Nothing to set in Crystal — just call Tray.setMenu from JS.
```

```js
Tray.setMenu([{ id: "quit", label: "Quit" }]);
```

**Left toggles window, right shows menu (popover style):**

```crystal
opts.tray.toggle_window_on = [:left_click]
```

**Both clicks open the menu, regardless of overrides:**

```crystal
opts.tray.on_click       = -> { Lune::Native::Tray.popup_menu; nil }
opts.tray.on_right_click = -> { Lune::Native::Tray.popup_menu; nil }
```

---

## Windows notes

Tray ships fully on Windows via `Shell_NotifyIconW` + `CreatePopupMenu` + `LoadImageW`. Three behavioural differences from macOS / Linux to be aware of:

- **`Tray.setIcon` requires a `.ico` file.** Pass a path ending in `.ico`; PNG / SVG / JPEG fall back to the default Windows app icon (`IDI_APPLICATION`) and emit a `logger.warn`. Convert your icon at build time — the bundled `assets/lune-logo.ico` is a multi-resolution example (16/32/48/64/128/256 px embedded as PNG entries) generated from `assets/lune-logo.png`.
- **`opts.tray.toggle_window_on` is currently a no-op on Windows.** The macOS implementation positions the window directly under the tray icon using the icon's screen rect; on Windows that requires `Shell_NotifyIconGetRect` plumbing that isn't wired yet. The click handler still fires — it just doesn't move or show the window. Tracked in [ROADMAP.md](https://github.com/AristoRap/lune/blob/main/ROADMAP.md). Until then, wire `opts.tray.on_click = -> { ... }` manually if you want click-to-toggle behaviour on Windows.
- **Native context menus render at the cursor position**, not anchored to the tray icon (this matches Win32 convention — `TrackPopupMenu` takes screen coordinates and Lune passes `GetCursorPos`). The Win32 menu also uses the system's classic submenu style, not the rounded "Mica" popovers you see in some Windows 11 apps — those require Acrylic / DirectComposition work that isn't in scope.

---

## Platform notes

- **macOS** — Verified.
- **Linux** — Untested. Requires XWayland on Wayland compositors.
- **Windows** — Verified with caveats. Core functionality (icon, menu, click, right-click) works via `Shell_NotifyIconW`. `setIcon` requires `.ico` (PNG/SVG fall back to default with warning); `toggle_window_on` is a no-op (needs `Shell_NotifyIconGetRect`); native menus render at cursor position rather than anchored to icon.

---

## Disabling

```yaml
plugins:
  disabled:
    - tray
```
