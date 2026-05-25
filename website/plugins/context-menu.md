# ContextMenu

> Programmatic native context menus triggered on right-click.

|                  |                          |
| ---------------- | ------------------------ |
| **Config key**   | `context_menu`           |
| **JS namespace** | `ContextMenu`            |
| **Core**         | No                       |
| **Phases**       | Bindable · WebviewInject |
| **Hard deps**    | `event`                  |
| **Platforms**    | macOS · Linux · Windows  |

ContextMenu lets you declare a menu that appears on right-click. Items are identified by string IDs; selection fires a `context_menu` event back through Event.

Disabling `event` automatically disables this plugin.

---

## Enabling

```yaml
plugins:
  enabled:
    - context_menu
    - event # required
```

Or omit `plugins:` entirely to enable everything.

---

## Crystal options

```crystal
Lune.run(app) do |opts|
  opts.context_menu.block_default = true
end
```

| Option          | Type   | Default | Description                                                                                                                                                                                                                          |
| --------------- | ------ | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `block_default` | `Bool` | `false` | When `true`, suppresses the browser's default right-click menu via a single `preventDefault` listener. Useful when you want a blanket block plus a custom native menu in specific places, or just no browser menu and no native one. |

> When you call `lune.ContextMenu.set(...)` from JS, the menu replaces the browser's default automatically — `block_default` is only needed for "no browser menu, no native menu" or "block by default, native only where I `set` it".

---

## JavaScript API

```js
import { lune } from "../lunejs/runtime/runtime.js";

// Set the items that appear on right-click
lune.ContextMenu.set([
  { id: "copy", label: "Copy" },
  { id: "paste", label: "Paste" },
  { id: "delete", label: "Delete" },
]);

// Listen for a selection
lune.ContextMenu.onSelect((id) => {
  console.log("Selected:", id);
});

// Remove the menu
lune.ContextMenu.clear();
```

| Method     | Signature      | Description                                  |
| ---------- | -------------- | -------------------------------------------- |
| `set`      | `set(items)`   | Declare menu items; replaces the current set |
| `clear`    | `clear()`      | Remove all items (disables right-click menu) |
| `onSelect` | `onSelect(cb)` | Persistent listener for item selection       |

### Menu item shape

`set` takes an array of `{ id?: string; label?: string; enabled?: boolean; separator?: boolean }`. The shape is inlined in `runtime.d.ts` — Lune doesn't ship a named `ContextMenuItem` interface. All fields are optional; use `separator: true` for a divider.

```ts
lune.ContextMenu.set([
  { id: "copy", label: "Copy" },
  { id: "paste", label: "Paste", enabled: false },
  { separator: true },
  { id: "delete", label: "Delete" },
]);
```

---

## Notes

- `lune.ContextMenu.set` and `lune.ContextMenu.clear` are synchronous — they update a JS-side registry that intercepts the `contextmenu` DOM event.
- The native menu is shown by a Crystal binding call; the selected item ID is emitted back as a `context_menu` event on Event.
- Only one context menu set is active at a time. Call `set` again to update the items.
- To show different menus on different elements, call `set` in a `contextmenu` event listener on the target before it propagates.

---

## Platform notes

- **macOS** — Verified.
- **Linux** — Untested.
- **Windows** — Partial. Custom Win32 menu works via `TrackPopupMenu`, but WebView2's built-in browser context menu shows on top.

---

## Disabling

```yaml
plugins:
  disabled:
    - context_menu
```
