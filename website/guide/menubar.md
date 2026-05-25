# Menubar Apps

Menubar mode turns your Lune app into a tray-driven utility: the OS app-switcher entry is hidden (Dock on macOS, taskbar + Alt+Tab on Windows), the window starts invisible, and a tray icon appears in the menu bar / system tray. The window stays out of the way until you bring it forward — typically from a menu item, or by opting clicks into the built-in window toggle.

---

## Quick start

```crystal
# src/main.cr
Lune.run(app, assets: "frontend/dist") do |opts|
  opts.width  = 380
  opts.height = 500
  opts.menubar_mode = true

  # macOS-specific chrome polish (no traffic lights, full-bleed content).
  opts.mac do |m|
    m.full_size_content   = true
    m.hide_traffic_lights = true
  end

  # Optional: make left-click drop the window down under the tray icon.
  # Without this, clicks just show the menu (if set) or emit `trayEvent`.
  opts.tray do |t|
    t.toggle_window_on = [:left_click]
  end
end
```

Optionally set a custom icon from JavaScript once the app has mounted:

```js
import { lune } from "../lunejs/runtime/runtime.js";

// Falls back to ● if not called
await lune.Tray.setIcon("/absolute/path/to/icon.png");
```

---

## What `menubar_mode` actually does

It's a small preset of window-state flags:

1. Hides the app from the OS app switcher — `NSApplicationActivationPolicyAccessory` on macOS, `WS_EX_TOOLWINDOW` (no taskbar entry, no Alt+Tab) on Windows.
2. Hides the window immediately after creation.
3. Wires an auto-hide-on-focus-loss observer — `NSWindowDidResignKeyNotification` on macOS, `WM_ACTIVATEAPP` on Windows.
4. Auto-enables `opts.tray.auto_show` so the tray icon appears at boot.

It does **not** wire any click-to-window behavior. That's `opts.tray.toggle_window_on`'s job — see below. The split keeps menubar-only apps (Docker, Slack — menu-driven) and popover-style apps (Bartender, MeetingBar — click toggles a window) cleanly distinguishable.

Window frame is **never** saved or restored in menubar mode. Size (`width` / `height`) is respected; position is recalculated from the tray icon on each toggle.

---

## Click behaviour

Per click direction (left or right), the first rule that matches wins:

1. **User override set** (`opts.tray.on_click` / `on_right_click`) — fires the callback. Full takeover.
2. **Click listed in `toggle_window_on`** — toggles the window (positioned under the tray icon on macOS).
3. **A menu is set** — shows the menu.
4. **Otherwise** — emits `trayEvent` with payload `"left_click"` or `"right_click"`.

That's the whole model. Examples:

```crystal
# Docker-style: both clicks show the menu, menu item opens the window.
opts.tray do |t|
  # Nothing to set. Just attach a menu from JS and you're done.
end
```

```crystal
# Popover-style: left toggles window, right shows menu.
opts.tray do |t|
  t.toggle_window_on = [:left_click]
end
```

```crystal
# Both clicks toggle the window, no menu at all.
opts.tray do |t|
  t.toggle_window_on = [:left_click, :right_click]
end
```

```crystal
# Full custom: I'll handle clicks myself.
opts.tray do |t|
  t.on_click       = -> { do_my_thing }
  t.on_right_click = -> { do_my_other_thing }
end
```

---

## Context menu

Set a context menu with `lune.Tray.setMenu`. With no `toggle_window_on` set, both clicks open the menu (rule 3 above):

```js
import { lune } from "../lunejs/runtime/runtime.js";

lune.Tray.setMenu([
  { id: "show", label: "Open Window" },
  { id: "---", label: "" },
  { id: "quit", label: "Quit" },
]);

lune.Event.on("trayEvent", (id) => {
  if (id === "show") lune.Window.show();
  if (id === "quit") lune.System.quit();
});
```

`{ id: "---" }` renders a separator.

If you want left-click to toggle the window and right-click to show the menu, add `toggle_window_on = [:left_click]` in Crystal — left-click is then on rule 2 (toggle) and right-click falls through to rule 3 (menu).

---

## Programmatic menu popup

Need to open the menu from your own click handler, a keyboard shortcut, or anywhere else? `lune.Tray.popupMenu()` opens whatever menu was last set.

```crystal
opts.tray.on_click = -> {
  do_some_work
  Lune::Native::Tray.popup_menu # show the menu anyway after the work
  nil
}
```

```js
import { lune } from "../lunejs/runtime/runtime.js";

// e.g. from a global keyboard shortcut
await lune.Tray.popupMenu();
```

If no menu has been set, the call returns without doing anything.

---

## Window control from JS

When you're managing visibility yourself (custom `on_click`, menu items, etc.):

```js
import { lune } from "../lunejs/runtime/runtime.js";

await lune.Window.show();
await lune.Window.hide();
```

---

## Recommended chrome options

Menubar windows typically look best without a title bar:

```crystal
opts.menubar_mode = true
opts.mac do |m|
  m.full_size_content   = true  # content extends under title bar
  m.hide_traffic_lights = true  # no close/minimise/zoom buttons
  m.hide_title          = true  # no title text
end
opts.width  = 380
opts.height = 500
```

---

## Platform support

| Platform | Status                                                                                                       |
| -------- | ------------------------------------------------------------------------------------------------------------ |
| macOS    | Supported                                                                                                    |
| Windows  | Supported — `WS_EX_TOOLWINDOW` hides from taskbar + Alt+Tab; `WM_ACTIVATEAPP` triggers auto-hide on blur     |
| Linux    | Not yet wired — `opts.menubar_mode = true` is silently ignored                                               |
