# ContextMenu

> Programmatic native context menus triggered on right-click.

|                  |                                  |
| ---------------- | -------------------------------- |
| **Config key**   | `context_menu`                   |
| **JS namespace** | `ContextMenu`                    |
| **Core**         | No                               |
| **Phases**       | Bindable · WebviewInject         |
| **Hard deps**    | `events`                         |
| **Platforms**    | macOS (Windows/Linux: planned) |

ContextMenu lets you declare a menu that appears on right-click. Items are identified by string IDs; selection fires a `context_menu` event back through Events.

Disabling `events` automatically disables this capability.

---

## Enabling

```yaml
capabilities:
  include:
    - context_menu
    - events # required
```

Or omit `capabilities:` entirely to enable everything.

---

## JavaScript API

```js
import { ContextMenu } from "../lunejs/runtime/runtime.js";

// Set the items that appear on right-click
ContextMenu.set([
  { id: "copy", label: "Copy" },
  { id: "paste", label: "Paste" },
  { id: "delete", label: "Delete" },
]);

// Listen for a selection
ContextMenu.onSelect((id) => {
  console.log("Selected:", id);
});

// Remove the menu
ContextMenu.clear();
```

| Method     | Signature      | Description                                  |
| ---------- | -------------- | -------------------------------------------- |
| `set`      | `set(items)`   | Declare menu items; replaces the current set |
| `clear`    | `clear()`      | Remove all items (disables right-click menu) |
| `onSelect` | `onSelect(cb)` | Persistent listener for item selection       |

### `ContextMenuItem`

```ts
interface ContextMenuItem {
  id: string;
  label: string;
}
```

---

## Notes

- `ContextMenu.set` and `ContextMenu.clear` are synchronous — they update a JS-side registry that intercepts the `contextmenu` DOM event.
- The native menu is shown by a Crystal binding call; the selected item ID is emitted back as a `context_menu` event on Events.
- Only one context menu set is active at a time. Call `set` again to update the items.
- To show different menus on different elements, call `set` in a `contextmenu` event listener on the target before it propagates.

---

## Disabling

```yaml
capabilities:
  exclude:
    - context_menu
```
