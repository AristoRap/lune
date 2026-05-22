# ContextMenuBlocker

> Block the browser's default right-click menu when `opts.disable_context_menu` is set.

|                  |                         |
| ---------------- | ----------------------- |
| **Config key**   | `context_menu_blocker`  |
| **JS namespace** | — (no namespace)        |
| **Core**         | No                      |
| **Phases**       | WebviewInject           |
| **Hard deps**    | —                       |
| **Platforms**    | macOS · Linux · Windows |

A passive plugin that injects a single-line `contextmenu` listener calling `e.preventDefault()`, but only when `opts.disable_context_menu = true`. Independent of the [ContextMenu](./context-menu) plugin — that one _shows_ custom native menus; this one _blocks_ the WebView's default.

---

## Crystal options

```crystal
Lune.run(app) do |opts|
  opts.disable_context_menu = true
end
```

| Option                 | Type   | Default | Description                                                                      |
| ---------------------- | ------ | ------- | -------------------------------------------------------------------------------- |
| `disable_context_menu` | `Bool` | `false` | When `true`, suppresses the browser's default context menu via `preventDefault`. |

---

## Relationship to ContextMenu

The [ContextMenu](./context-menu) plugin suppresses the browser menu **only while** a custom menu is actively registered via `window.__lune.setContextMenu(items)` — at all other times (and on elements outside the custom menu's scope) the browser menu shows.

`ContextMenuBlocker` suppresses the browser menu **unconditionally** whenever `opts.disable_context_menu = true`. Use both when you want a blanket block plus a custom native menu in specific places.

---

## Disabling

```yaml
plugins:
  disabled:
    - context_menu_blocker
```

Disabling the cap means `opts.disable_context_menu = true` has no effect — the browser menu shows regardless.

---

## Platform notes

- **macOS** — Verified.
- **Linux** — Untested.
- **Windows** — Verified.
