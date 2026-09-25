# Window

> Programmatic window controls from JavaScript and an opt-in CSS-driven window drag listener.

|                  |                          |
| ---------------- | ------------------------ |
| **Config key**   | `window`                 |
| **JS namespace** | `Window`                 |
| **Core**         | No                       |
| **Phases**       | Bindable · WebviewInject |
| **Hard deps**    | —                        |
| **Platforms**    | macOS · Linux · Windows  |

The Window plugin exposes runtime window controls to JavaScript — minimize, maximize, center, resize, retitle — and a CSS-driven drag listener for custom title bars. For initial window size, title, and macOS chrome options, see [Window Configuration](../guide/window).

---

## JavaScript API

```js
import { lune } from "../lunejs/runtime/runtime.js";

await lune.Window.minimize();
await lune.Window.maximize();
await lune.Window.center();

await lune.Window.setTitle({ title: "My App — Unsaved" });
await lune.Window.setSize({ width: 1440, height: 900 });
```

| Method     | Signature                    | Returns         |
| ---------- | ---------------------------- | --------------- |
| `minimize` | `minimize()`                 | `Promise<void>` |
| `maximize` | `maximize()`                 | `Promise<void>` |
| `center`   | `center()`                   | `Promise<void>` |
| `setTitle` | `setTitle({ title })`        | `Promise<void>` |
| `setSize`  | `setSize({ width, height })` | `Promise<void>` |

`lune.Window.startDrag` is also exposed but is invoked by the auto-injected mousedown listener — application code rarely calls it directly.

---

## Window drag _(macOS + Windows)_

Tag DOM elements with a CSS custom property and mousedown on them initiates a native window drag. Essential when using a custom title bar without the OS chrome.

```crystal
Lune.run(app) do |opts|
  opts.window.drag_zone = "--lune-draggable"
end
```

| Option         | Type     | Default                      | Description                                                                                                                                   |
| -------------- | -------- | ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `drag_zone`    | `String` | `""`                         | Inline CSS custom property that marks drag handles or excludes subtrees. Empty disables dragging.                                             |
| `drag_exclude` | `String` | Interactive elements (below) | CSS selector for elements whose entire subtree must keep pointer interaction. Override for custom widgets; `""` disables selector exclusions. |

Mark an element as a drag handle with an inline style. Non-empty values enable dragging, except `false`, `0`, and `no-drag`, which exclude a subtree. Write `true` for clarity:

```html
<div style="--lune-draggable: true">Title bar</div>
```

> **Inline style required.** Detection reads `style.getPropertyValue` directly. The event's composed path is checked, including ancestors across shadow roots. Exclusions always win, even over a nested drag handle.

You can mark the entire app draggable and opt custom interaction areas out:

```html
<div style="--lune-draggable: true">
  <h1>Drag from this heading or the background</h1>
  <button>Buttons remain clickable automatically</button>
  <div style="--lune-draggable: false">Selectable text or a custom widget</div>
  <div data-lune-no-drag>Another custom interaction area</div>
</div>
```

By default, `drag_exclude` includes links, buttons, inputs, selects, textareas, labels, summaries, editable regions, elements with `tabindex`, ARIA buttons/links/sliders/checkboxes/switches/tabs/menuitems/comboboxes, HTML drag sources, `[data-lune-no-drag]`, dialogs, SVG, and canvas. Their descendants are excluded too. Disabled controls also remain excluded. The `data-lune-no-drag` attribute is part of this default selector; inline `false`/`0`/`no-drag` exclusions always apply, even with a custom selector.

For custom selectors, assign `opts.window.drag_exclude` (this replaces the default selector). Unmodified primary-button presses initiate dragging; secondary buttons, modifier clicks, already-cancelled events, and native scrollbar presses retain their normal behavior. Text in draggable regions cannot be selected by dragging; mark selectable content as no-drag.

When `drag_zone` is empty (the default), no mousedown listener is installed and the `start_drag` binding is unused — the plugin behaves exactly like before the drag feature existed. To "disable" drag, leave `drag_zone` unset.

---

## Notes

- `setSize` sets the content area in logical pixels (independent of screen DPI).
- For initial size and position constraints (`min_width`, `max_width`, etc.) use the [Window Configuration](../guide/window) options.

---

## Platform notes

- **macOS** — Verified. Programmatic controls + drag both work.
- **Linux** — Untested. Programmatic controls only — `drag_zone` has no effect (drag needs `_NET_WM_MOVERESIZE`; tracked in [ROADMAP.md](https://github.com/AristoRap/lune/blob/main/ROADMAP.md)).
- **Windows** — Verified. Programmatic controls + `drag_zone` (mousedown → `ReleaseCapture` + `SendMessage(WM_NCLBUTTONDOWN, HTCAPTION, 0)`). Window state opt-in via `remember_frame = true` (live `GetWindowRect` tracker since HWND is destroyed before save). Chrome opts are macOS-only.

---

## Disabling

```yaml
plugins:
  disabled:
    - window
```

This turns off everything — the JS bindings AND the drag listener. To keep the programmatic controls but turn off drag, leave `opts.window.drag_zone` empty (the default).
